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
				
				'Done!'
           } ‘2’ {
                cls
                ‘Rules with zero hits created before:’
				
				'Done!'
           }  ‘3’ {
                cls
                'Rules with zero hits created after:’
				
				'Done!'
           } ‘4’ {
                cls
                ‘Top 10 percent least hit rules (excluding zero hit rules):’
				
				'Done!'
            } ‘5’ {
                cls
                ‘Top 10 percent most hit rules:’
				
				'Done!'
           } ‘b’ {
                return
           }
     }
     pause
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
     
     Write-Host “1: List all rules sorted by creation date”
     Write-Host “2: List all rules older than 'X' days”
     Write-Host “3: List all rules newer than 'X' days”
     Write-Host “Q: Enter ‘B’ to go back to Main Menu"
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
				
				'Done!'
           } ‘2’ {
                cls
                "Rules older than 'X' days"
				
				'Done!'
            } ‘3’ {
                cls
                "List all rules newer than 'X' days"
				
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
                Write-Host "Rules that are not leveraging 'Applied To':"

           } ‘q’ {
                cls
                Write-Host "Good-bye"
                return
           }
     }
     pause
}
until ($input -eq ‘q’)
