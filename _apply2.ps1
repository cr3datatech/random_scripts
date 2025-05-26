# PowerShell script to display a selection menu and execute a corresponding script

Write-Host "APPLY MENU. CHOOSE ACCOUNT TO APPLY CHANGES TO"

# Call list_profiles.ps1 and capture output
$listProfilesScript = ".\list_profiles.ps1" -split " "

if (Test-Path $listProfilesScript) {
    $accounts = & $listProfilesScript  # Execute and store the output as an array
	Write-Host $accounts
} else {
    Write-Host "Error: list_profiles.ps1 not found!"
    exit 1
}

# Ensure the accounts list is not empty
if ($accounts.Count -eq 0) {
    Write-Host "No profiles found. Exiting..."
    exit 1
}

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
