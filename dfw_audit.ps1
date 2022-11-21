# Temporarily hard setting nsxmgr and credentials for development. Get-Credential will be used in the future. 

$nsxmgr = '172.16.10.11'
$nsxuser = 'admin'
$nsxpasswd = ConvertTo-SecureString -String 'VMware1!VMware1!' -AsPlainText -Force
$Cred = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $nsxuser, $nsxpasswd
$Uri = 'https://'+$nsxmgr+'/policy/api/v1/infra?type_filter=SecurityPolicy'

#$nsxmgr = Read-Host "Enter NSX Manager IP or FQDN"
#$Cred = Get-Credential -Title 'NSX Manager Credentials' -Message 'Enter NSX Username and Password'


# All fuctions beginning with 'Get-NSXDFW' will run at script initiation. All other functions will be
# called via menu selection. 


function Get-NSXDFW($Uri){

	# The below gathers all securitypolicies in the $rawpolicy variable 

	Write-Host "Requesting data from target NSX Manager..."
	

	$rawpolicy = Invoke-RestMethod -Uri $Uri -SkipCertificateCheck -Authentication Basic -Credential $Cred 


	# Gathering security policies and rules
	
	Write-Host "Gathering DFW Security Policies and rules..."

	$secpolicies = $rawpolicy.children.Domain.children.SecurityPolicy | Where-object {$_.id -And $_._create_user -ne 'system' -And $_._system_owned -eq $False}
	$allrules = @()
	$allnoappliedtopolicyrules = @()
	$noappliedtopolicy = $()
	foreach ($secpolicy in $secpolicies){
		$noappliedtopolicy = $secpolicy | Where-Object {$_.scope -eq "ANY"}
		$noappliedtopolicyrules = $noappliedtopolicy.children.Rule
		foreach ($rule in $noappliedtopolicyrules | Where-Object {$_.id}){
			$allnoappliedtopolicyrules += $rule
		}
		$secpolrules = $secpolicy.children.Rule
		foreach ($rule in $secpolrules){
			$allrules += $rule
		}
	}


	return $secpolicies, $allrules, $allnoappliedtopolicyrules
	
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

function Get-NSXDFWNoHitRules($allpolstats, $allrules){
	$nohitrules = @()
	foreach ($polstat in $allpolstats){
		$polrulestat = $polstat.results.statistics.results
		foreach ($rulestat in $polrulestat | Where-object {$_.hit_count -eq '0'}){
			$nohitrules += $rulestat
		}	
	}
	return $nohitrules
}


#Menu called functions

function Get-TargetDate(){
	[int]$input_days = Read-Host "Input number of days ago"
	[int]$daysdelta = $input_days * 86400
	[int]$currentdate = get-date -UFormat %s
	$targetdate = ($currentdate - $daysdelta) * 1000
	return $targetdate
}

function Get-AllNoHitRules($nohitrules, $allrules){
	$sortnohitrules = @()
	foreach ($rulestat in $nohitrules){
		foreach ($rule in $allrules | Where-object {$_.rule_id -match ($rulestat.internal_rule_id)}){
			$sortnohitrules += $rule
		}
	}	
	$sortnohitrules = $sortnohitrules | Sort-Object -Property _create_time 
	foreach ($rule in $sortnohitrules){
			[int]$rulecreatetime = $rule._create_time / 1000
			Write-Host "Rule ID"($rule.rule_id)($rule.display_name)"has zero hits -- Created on"(Get-Date -UnixTimeSeconds $rulecreatetime)
		}
}

function Get-NoHitRulesOlderThan($nohitrules, $allrules, $targetdate){
	$sortnohitrules = @()
	foreach ($nohitrule in $nohitrules){
		foreach ($rule in $allrules | Where-object {$_.rule_id -match ($nohitrule.internal_rule_id) -And $_._create_time -lt $targetdate}){
			$sortnohitrules += $rule
		}	
	}
	$sortnohitrules = $sortnohitrules | Sort-Object -Property _create_time
	foreach ($rule in $sortnohitrules){
		[int]$rulecreatetime = $rule._create_time / 1000
		Write-Host "Rule ID"($rule.rule_id)($rule.display_name)"has zero hits -- Created on"(Get-Date -UnixTimeSeconds $rulecreatetime)
	}
}

function Get-TopTenHitRules($allpolstats, $allrules){
	$sorthitrules = $allpolstats.results.statistics.results | Sort-Object -Property hit_count -Descending
	$tenpercent = [math]::ceiling($sorthitrules.count * .1)
	for ( $index = 0; $index -lt $tenpercent; $index++){
		foreach ($rule in $allrules | Where-object {$_.rule_id -match ($sorthitrules[$index].internal_rule_id)}){
			Write-Host "Rule ID"($rule.rule_id)($rule.display_name)"has"($sorthitrules[$index].hit_count)"hits"
		}
	}
}

function Get-BottomTenHitRules($allpolstats, $allrules){
	$sorthitrules = $allpolstats.results.statistics.results | Where-Object -Property hit_count -ne 0 | Sort-Object -Property hit_count
	$tenpercent = [math]::ceiling($sorthitrules.count * .1)
	for ( $index = 0; $index -lt $tenpercent; $index++){
		foreach ($rule in $allrules | Where-object {$_.rule_id -match ($sorthitrules[$index].internal_rule_id)}){
			Write-Host "Rule ID"($rule.rule_id)($rule.display_name)"has"($sorthitrules[$index].hit_count)"hits"
		}
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

$allsecpolicies, $allrules, $allnoappliedtopolicyrules = Get-NSXDFW $Uri
$allstats = Get-NSXDFWStats $allsecpolicies
$nohitrules = Get-NSXDFWNoHitRules $allstats $allrules
#$targetdate = Get-TargetDate



