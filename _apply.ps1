# PowerShell script to display a selection menu and execute a corresponding script

Write-Host "APPLY MENU. CHOOSE ACCOUNT TO APPLY CHANGES TO"

# Define the list of accounts
$accounts = @(
    "01-fennia-analytics-dev-cc1711_276151778847",
    "02-Fennia-Analytics-Prod-cc1711_276627978646",
    "03-fennia-data-prod-cc1711_003292245041",
    "04-fenniafi-dev-KP1707_809857356695",
    "05-fenniafi-KP1707_796026331007",
    "06-fenniafi-test-KP1707_825034570200",
    "07-fennia-pricing-dev-cc1711_287744729310",
    "08-OF-Dev-KP1707_408584285563",
    "09-OF-KP1707_365008017981",
    "10-OF-Test-KP1707_810814827424",
	"11- dummy_entry"
)

Write-Host $accounts

# Function to display the menu and process the selection
function Show-Menu {
    for ($i = 0; $i -lt $accounts.Length; $i++) {
        Write-Host "$($i + 1)) $($accounts[$i])"
    }

    do {
        $selection = Read-Host "Enter your choice (1-$($accounts.Length))"

        if ($selection -match "^\d+$") {
            $index = [int]$selection - 1

            if ($index -ge 0 -and $index -lt $accounts.Length) {
                $selectedAccount = $accounts[$index]
                Write-Host "The selected account is $selectedAccount"
                
                # Construct the script path and execute it
                $scriptPath = ".\apply_scripts\apply-$selectedAccount.ps1"

                if (Test-Path $scriptPath) {
                    & $scriptPath  # Executes the script
                } else {
                    Write-Host "Script not found: $scriptPath"
                }

                break
            }
        }
        Write-Host "Wrong selection: Select any number from 1-$($accounts.Length)"
    } while ($true)
}

# Call the menu function
Show-Menu
