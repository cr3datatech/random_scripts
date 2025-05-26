# Define the config and credentials file paths
$configFile = "$HOME\.aws\config"
$credentialsFile = "$HOME\.aws\credentials"

# Prompt the user to enter the hosted zone ID
#$hostedZoneId = Read-Host "Please enter the hosted zone ID"
$hostedZoneId = "Z05838601JZY96YSPTK4L" # Replace with the actual hosted zone ID you're checking for

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
# $configProfiles = Extract-Profiles -filePath $configFile
$configProfiles = Extract-Profiles -filePath $configFile | Where-Object { $_ -like "fennia*" }

# Extract profiles from credentials file
if (Test-Path $credentialsFile) {
    $credentialProfiles = Get-Content $credentialsFile | Select-String -Pattern "^\[" | ForEach-Object { $_ -replace '^\[(.+)\]', '$1' }
}

# Combine profiles, excluding those that end with '-config'
# $allProfiles = ($configProfiles + $credentialProfiles) | Where-Object { $_ -notmatch '-config$' } | Sort-Object -Unique
$allProfiles = ($configProfiles) | Where-Object { $_ -notmatch '-config$' } | Sort-Object -Unique

Write-Host "Checking for hosted zone in AWS CLI profiles:"
Write-Host "Hosted Zone ID: $hostedZoneId"

foreach ($profile in $allProfiles) {
    Write-Host "Checking profile: $profile"
    $result = aws route53 list-hosted-zones --profile $profile --output text 2>$null | Select-String -Pattern $hostedZoneId
    if ($result) {
        Write-Host "Hosted zone $hostedZoneId *** FOUND *** in profile: $profile"
		break
    } else {
        Write-Host "Nope"
    }
}
