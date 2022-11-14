# Temporarily hard setting nsxmgr and credentials for development. Get-Credential will be used in the future. 

$nsxmgr = '172.16.10.11'
$nsxuser = 'admin'
$nsxpasswd = ConvertTo-SecureString -String 'VMware1!VMware1!' -AsPlainText -Force
$Cred = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $nsxuser, $nsxpasswd

#$nsxmgr = Read-Host "Enter NSX Manager IP or FQDN"
#$Cred = Get-Credential -Title 'NSX Manager Credentials' -Message 'Enter NSX Username and Password'

# Uri will get only securitypolices, groups, and services under infra

$Uri = 'https://'+$nsxmgr+'/policy/api/v1/infra?type_filter=SecurityPolicy'
function Get-NSXDFW($Uri){

	# The below gathers all securitypolicies, groups, and services from global-infra, storing it in 
	# the $rawpolicy variable 

	Write-Host "Requesting data from target NSX Manager..."
	

	$rawpolicy = Invoke-RestMethod -Uri $Uri -SkipCertificateCheck -Authentication Basic -Credential $Cred 


	# Gathering security policies and rules
	
	Write-Host "Gathering DFW Security Policies and rules..."

	$secpolicies = $rawpolicy.children.Domain.children.SecurityPolicy | Where-object {$_.id -And $_.id -ne 'Default'}
	$filteredsecpol = @()


	foreach ($secpolicy in $secpolicies | Where-object {$_._create_user -ne 'system' -And $_._system_owned -eq $False}){
				$secpolicy = $secpolicy | Select-Object -ExcludeProperty path,relative_path,unique_id,realization_id,parent_path,marked_for_delete,overridden,internal_sequence_number,locked, lock_modified_time, is_default,_*,target_type
		

				$filteredrules = @()
				foreach ($rule in $secpolicy.children | Where-object {$_.id}){
						$rule = $rule | Select-Object -ExcludeProperty marked_for_delete,mark_for_override,_* 
						$rule.Rule = $rule.Rule | Select-Object -ExcludeProperty marked_for_delete,path,relative_path,parent_path,unique_id,realization_id,overridden,rule_id,is_default,_*,children
						$filteredrules += $rule
				}
			

				$secpolicy.children = $filteredrules
				$filteredsecpol += $secpolicy
	}

	return $filteredsecpol
	<#
	
	# Gathering Groups

	Write-Host "Gathering Groups..."

	$allgroups = $rawpolicy.children.Domain.children.Group | Where-object {$_.id}
	$filteredgroups = @()

	foreach ($group in $allgroups | Where-object {$_._system_owned -eq $False -And $_._create_user -ne 'system'}){
			$group = $group | Select-Object -ExcludeProperty reference,path,relative_path,parent_path,unique_id,realization_id,marked_for_delete,overridden,_*
					
			$filteredgroups += $group
	}


	# Gathering Services

	Write-Host "Gathering Serivces..."

	$allservices = $rawpolicy.children.Service | Where-object {$_.id}
	$filteredsvc = @()

	foreach ($svc in $allservices | Where-object {$_.is_default -ne $true}){
				$svc = $svc | Select-Object -ExcludeProperty is_default,path,relative_path,parent_path,unique_id,realization_id,marked_for_delete,overridden,_*
				$svc_entries = @()
				foreach ($svc_entry in $svc.service_entries | Where-object {$_.id}){
						$svc_entry = $svc_entry | Select-Object resource_type,children
						$svc_entries += $svc_entry 
				}
				$svc.service_entries = $svc_entries

				$filteredsvc += $svc
	}

	# Gathering Context Profiles

	Write-Host "Gathering Context Profiles..."

	$allcontextprofiles = $rawpolicy.children.PolicyContextProfile | Where-object {$_.id}
	$filteredcontextprofiles = @()

	foreach ($contextprofile in $allcontextprofiles | Where-object {$_._create_user -ne 'system' -And $_._system_owned -ne $true}){
			$contextprofile = $contextprofile | Select-Object -ExcludeProperty path,relative_path,parent_path,unique_id,realization_id,marked_for_delete,overridden,_*
			$filteredcontextprofiles += $contextprofile
	}

#>
}




<#

# Main Menu

function Show-Menu
{
     param (
           [string]$Title = ‘NSX DFW Configuration backup/migration’
     )
     cls
     Write-Host “================ $Title ================”
     
     Write-Host “1: Press ‘1’ for Local to Local NSX Manager DFW backup/migration.”
     Write-Host “2: Press ‘2’ for Global (Federation) to Local NSX Manager DFW backup/migration .”
     Write-Host “Q: Press ‘Q’ to quit.”
}

# Main

do
{
     Show-Menu
     $input = Read-Host “Please make a selection”
     switch ($input)
     {
           ‘1’ {
                cls
                ‘Generating polcy.json file for Local to Local NSX Manager DFW backup/migration...’
				$Uri = 'https://'+$nsxmgr+'/policy/api/v1/infra?type_filter=SecurityPolicy;Group;Service;PolicyContextProfile'
				$infra = Get-NSXDFW($Uri)
				New-NSXLocalInfra
				'Done!'
           } ‘2’ {
                cls
                ‘Generating global-policy.json file for Global (Federation) to Local NSX Manager DFW backup/migration...’
				$Uri = 'https://'+$nsxmgr+'/global-manager/api/v1/global-infra?type_filter=SecurityPolicy;Group;Service;PolicyContextProfile'
				$infra = Get-NSXDFW($Uri)
				New-NSXGlobalInfra
				'Done!'
           } ‘q’ {
                return
           }
     }
     pause
}
until ($input -eq ‘q’)

#>

$infra = Get-NSXDFW($Uri)
$infra