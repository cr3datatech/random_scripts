# Define the config and credentials file paths
$configFile = "$HOME\.aws\config"
$credentialsFile = "$HOME\.aws\credentials"
clear

# Function to extract profiles from a given file
function Extract-Profiles {
    param (
        [string]$filePath
    )
    if (Test-Path $filePath) {
        Get-Content $filePath | Select-String -Pattern "^\[profile " | ForEach-Object { $_ -replace '^\[profile (.+)\]', '$1' }
    }
}

# Extract profiles from config file
$configProfiles = Extract-Profiles -filePath $configFile

# Extract profiles from credentials file
if (Test-Path $credentialsFile) {
    $credentialProfiles = Get-Content $credentialsFile | Select-String -Pattern "^\[" | ForEach-Object { $_ -replace '^\[(.+)\]', '$1' }
}

# Combine and sort profiles, removing duplicates
#$allProfiles = ($configProfiles + $credentialProfiles) | Sort-Object -Unique
$allProfiles = ($configProfiles) | Where-Object { $_ -notmatch '-config$' } | Sort-Object -Unique

##Write-Host "Configured AWS CLI profiles:"
##$allProfiles

$formattedProfiles = $allProfiles -join '" "'
Write-Host "`"$formattedProfiles`""
