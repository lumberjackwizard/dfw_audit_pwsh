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
			Write-Host "Rule ID"($rule.rule_id)"-"($rule.display_name)"has zero hits -- Created on"(Get-Date -UnixTimeSeconds $rulecreatetime)
		}
}

function Get-NoHitRulesOlderThan($nohitrules, $allrules, $targetdate){
	$sortnohitrules = @()
	foreach ($nohitrule in $nohitrules){
		foreach ($rule in $allrules | Where-object {$_.rule_id -match ($nohitrule.internal_rule_id) -And $_._create_time -le $targetdate}){
			$sortnohitrules += $rule
		}	
	}
	$sortnohitrules = $sortnohitrules | Sort-Object -Property _create_time
	foreach ($rule in $sortnohitrules){
		[int]$rulecreatetime = $rule._create_time / 1000
		Write-Host "Rule ID"($rule.rule_id)"-"($rule.display_name)"has zero hits -- Created on"(Get-Date -UnixTimeSeconds $rulecreatetime)
	}
}

function Get-NoHitRulesNewerThan($nohitrules, $allrules, $targetdate){
	$sortnohitrules = @()
	foreach ($nohitrule in $nohitrules){
		foreach ($rule in $allrules | Where-object {$_.rule_id -match ($nohitrule.internal_rule_id) -And $_._create_time -ge $targetdate}){
			$sortnohitrules += $rule
		}	
	}
	$sortnohitrules = $sortnohitrules | Sort-Object -Property _create_time
	foreach ($rule in $sortnohitrules){
		[int]$rulecreatetime = $rule._create_time / 1000
		Write-Host "Rule ID"($rule.rule_id)"-"($rule.display_name)"has zero hits -- Created on"(Get-Date -UnixTimeSeconds $rulecreatetime)
	}
}

function Get-TopTenHitRules($allpolstats, $allrules){
	$sorthitrules = $allpolstats.results.statistics.results | Sort-Object -Property hit_count -Descending
	$tenpercent = [math]::ceiling($sorthitrules.count * .1)
	for ( $index = 0; $index -lt $tenpercent; $index++){
		foreach ($rule in $allrules | Where-object {$_.rule_id -match ($sorthitrules[$index].internal_rule_id)}){
			Write-Host "Rule ID"($rule.rule_id)"-"($rule.display_name)"has"($sorthitrules[$index].hit_count)"hits"
		}
	}
}

function Get-BottomTenHitRules($allpolstats, $allrules){
	$sorthitrules = $allpolstats.results.statistics.results | Where-Object -Property hit_count -ne 0 | Sort-Object -Property hit_count
	$tenpercent = [math]::ceiling($sorthitrules.count * .1)
	for ( $index = 0; $index -lt $tenpercent; $index++){
		foreach ($rule in $allrules | Where-object {$_.rule_id -match ($sorthitrules[$index].internal_rule_id)}){
			Write-Host "Rule ID"($rule.rule_id)"-"($rule.display_name)"has"($sorthitrules[$index].hit_count)"hits"
		}
	}
}

function Get-RulesNoAppliedTo($allnoappliedtopolicyrules){
	foreach ($rule in $allnoappliedtopolicyrules | Where-Object {$_.id -And $_.scope -eq "ANY"}){
		Write-Host "Rule ID"($rule.rule_id)"-"($rule.display_name)
	}
}

function Get-AllRulesSorted($allrules){
	$sortrules = $allrules | Sort-Object -Property _create_time
	foreach ($rule in $sortrules){
		[int]$rulecreatetime = $rule._create_time / 1000
		Write-Host "Rule ID"($rule.rule_id)"-"($rule.display_name)"-- Created on"(Get-Date -UnixTimeSeconds $rulecreatetime)
	}
}

function Get-AllRulesOlderThan($allrules, $targetdate){
	$sortrules = @()
	
	foreach ($rule in $allrules | Where-object {$_.rule_id -And $_._create_time -le $targetdate}){
		$sortrules += $rule
	}	

	$sortrules = $sortrules | Sort-Object -Property _create_time
	foreach ($rule in $sortrules){
		[int]$rulecreatetime = $rule._create_time / 1000
		Write-Host "Rule ID"($rule.rule_id)"-"($rule.display_name)"-- Created on"(Get-Date -UnixTimeSeconds $rulecreatetime)
	}
}

function Get-AllRulesNewerThan($allrules, $targetdate){
	$sortrules = @()
	
	foreach ($rule in $allrules | Where-object {$_.rule_id -And $_._create_time -ge $targetdate}){
		$sortrules += $rule
	}	

	$sortrules = $sortrules | Sort-Object -Property _create_time
	foreach ($rule in $sortrules){
		[int]$rulecreatetime = $rule._create_time / 1000
		Write-Host "Rule ID"($rule.rule_id)"-"($rule.display_name)"-- Created on"(Get-Date -UnixTimeSeconds $rulecreatetime)
	}
}


#  Menu Systems

function Hit-Menu-Options
{
     param (
           [string]$Title = ‘NSX DFW Rule Hit queries’
     )
     cls
     Write-Host “================ $Title ================”
     
     Write-Host “1: List all rules with no hits”
     Write-Host “2: List all rules older than 'X' days with no hits”
     Write-Host “3: List all rules newer than 'X' days with no hits”
     Write-Host “4: List top ten percent least hit rules (excluding no hit rules)”
     Write-Host “5: List top ten percent most hit rules”
     Write-Host “B: Enter ‘B’ to go back to Main Menu"
}

function Hit-Menu {

do
{
     Hit-Menu-Options
     $input = Read-Host “Please make a selection”
     switch ($input)
     {
           ‘1’ {
                cls
                ‘All rules with zero hits (sorted by creation date):’
				''
				Get-AllNoHitRules $nohitrules $allrules
				pause
				'Done!'
           } ‘2’ {
                cls
				$targetdate = Get-TargetDate
				$printdate = Get-Date -UnixTimeSeconds ($targetdate / 1000)
				cls
                ‘Rules with zero hits created on or before '+$printdate
				''
				Get-NoHitRulesOlderThan $nohitrules $allrules $targetdate
				pause
				'Done!'
           }  ‘3’ {
                cls
				$targetdate = Get-TargetDate
				$printdate = Get-Date -UnixTimeSeconds ($targetdate / 1000)
				cls
                'Rules with zero hits created on or after ’+$printdate
				''
				Get-NoHitRulesNewerThan $nohitrules $allrules $targetdate
				pause
				'Done!'
           } ‘4’ {
                cls
                ‘Bottom 10 percent of rules by hit count (excluding zero hit rules):’
				''
				Get-BottomTenHitRules $allstats $allrules
				pause
				'Done!'
            } ‘5’ {
                cls
                ‘Top 10 percent of rules by hit count:’
				''
				Get-TopTenHitRules $allstats $allrules
				pause
				'Done!'
           } ‘b’ {
                return
           }
     }
     
}
until ($input -eq ‘b’)

}

function Age-Menu-Options
{
     param (
           [string]$Title = ‘NSX DFW Age/Date queries’
     )
     cls
     Write-Host “================ $Title ================”
     
     Write-Host “1: List all rules sorted by creation date (oldest to newest)”
     Write-Host “2: List all rules older than 'X' days”
     Write-Host “3: List all rules newer than 'X' days”
     Write-Host “B: Enter ‘B’ to go back to Main Menu"
}

function Age-Menu {

do
{
     Age-Menu-Options
     $input = Read-Host “Please make a selection”
     switch ($input)
     {
           ‘1' {
                cls
                ‘All rules sorted by creation date:’
				''
				Get-AllRulesSorted $allrules
				'Done!'
           } ‘2’ {
                cls
				$targetdate = Get-TargetDate
				$printdate = Get-Date -UnixTimeSeconds ($targetdate / 1000)
				cls
                "Rules created on or before "+$printdate
				''
				Get-AllRulesOlderThan $allrules $targetdate
				'Done!'
            } ‘3’ {
                cls
				$targetdate = Get-TargetDate
				$printdate = Get-Date -UnixTimeSeconds ($targetdate / 1000)
				cls
                "Rules created on or after "+$printdate
				''
				Get-AllRulesNewerThan $allrules $targetdate
				'Done!'
           } ‘b’ {
                return
           }
     }
     pause
}
until ($input -eq ‘b’)
}



function Main-Menu
{
     param (
           [string]$Title = ‘NSX DFW Audit Main Menu’
     )
     cls
     Write-Host “================ $Title ================”
     
     Write-Host “1: Show queries regarding rule hits”
     Write-Host “2: Show queries regarding rule age”
     Write-Host “3: List all rules not using 'Applied To' ”
     Write-Host “Q: Enter ‘Q’ to quit.”
}

# Main

#First gathering up all elements from NSX API that will be utilized by functions

$allsecpolicies, $allrules, $allnoappliedtopolicyrules = Get-NSXDFW $Uri
$allstats = Get-NSXDFWStats $allsecpolicies
$nohitrules = Get-NSXDFWNoHitRules $allstats $allrules


do
{
     Main-Menu
     $input = Read-Host “Please make a selection”
     switch ($input)
     {
           ‘1’ {
                cls
                Hit-Menu
				
           } ‘2' {
                cls
                Age-Menu
                
            } ‘3’ {
                cls
				Write-Host "Note: Rules may have 'Applied To' configured at the Security Policy level"
				Write-Host "and those rules are properly excluded from the below list"
                Write-Host "Rules that are not leveraging 'Applied To':"
				Get-RulesNoAppliedTo $allnoappliedtopolicyrules

           } ‘q’ {
                cls
                Write-Host "Good-bye"
                exit
           }
     }
     
}
until ($input -eq ‘q’)






