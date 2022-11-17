# Temporarily hard setting nsxmgr and credentials for development. Get-Credential will be used in the future. 

$nsxmgr = '172.16.10.11'
$nsxuser = 'admin'
$nsxpasswd = ConvertTo-SecureString -String 'VMware1!VMware1!' -AsPlainText -Force
$Cred = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $nsxuser, $nsxpasswd
$Uri = 'https://'+$nsxmgr+'/policy/api/v1/infra?type_filter=SecurityPolicy'

#$nsxmgr = Read-Host "Enter NSX Manager IP or FQDN"
#$Cred = Get-Credential -Title 'NSX Manager Credentials' -Message 'Enter NSX Username and Password'

# Uri will get only securitypolices, groups, and services under infra


function Get-NSXDFW($Uri){

	# The below gathers all securitypolicies, groups, and services from global-infra, storing it in 
	# the $rawpolicy variable 

	Write-Host "Requesting data from target NSX Manager..."
	

	$rawpolicy = Invoke-RestMethod -Uri $Uri -SkipCertificateCheck -Authentication Basic -Credential $Cred 


	# Gathering security policies and rules
	
	Write-Host "Gathering DFW Security Policies and rules..."

	$secpolicies = $rawpolicy.children.Domain.children.SecurityPolicy | Where-object {$_.id -And $_._create_user -ne 'system' -And $_._system_owned -eq $False}

	return $secpolicies
	
}

function Get-NSXDFWStats($secpolicies){
	$allpolstats = @()
	foreach ($secpol in $secpolicies){
		$api_policy_url = 'https://'+$nsxmgr+'/policy/api/v1/infra/domains/default/security-policies/'+$secpol.id+'/statistics'
		$polstats = Invoke-RestMethod -Uri $api_policy_url -SkipCertificateCheck -Authentication Basic -Credential $Cred 
		$allpolstats += $polstats
	}
	return $allpolstats
}

function Get-NSXDFWNoHitRules($allpolstats){
	$zerohitrules = @()
	foreach ($rulestat in $allpolstats | Where-object $_.hit_count -eq '0'){
		$zerohitrules += $rulestat
	}
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

$secpolicies = Get-NSXDFW($Uri)
$allstats = Get-NSXDFWStats($secpolicies)
$nohitrules = Get-NSXDFWNoHitRules($allstats)
$nohitrules

