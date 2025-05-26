cls

# Default SETTINGS
$num_accounts_to_return = 0
$print_details_to_terminal = 1
$output_table_to_terminal = 1
$export_to_csv = 1
$accounts_to_check = ""
$regions_to_check = ""

Write-Host "`n--- Script Configuration ---`n"

# Prompt for number of accounts
#$userInput = Read-Host "Enter number of accounts to check (default: $num_accounts_to_return)"
#if ($userInput -ne '') { $num_accounts_to_return = [int]$userInput }

# Prompt for print_details_to_terminal
$userInput = Read-Host "Print details to terminal? (0 = No, 1 = Yes) (default: $print_details_to_terminal)"
if ($userInput -ne '') { $print_details_to_terminal = [int]$userInput }

# Prompt for output_table_to_terminal
$userInput = Read-Host "Output summary table to terminal? (0 = No, 1 = Yes) (default: $output_table_to_terminal)"
if ($userInput -ne '') { $output_table_to_terminal = [int]$userInput }

# Prompt for export_to_csv
$userInput = Read-Host "Export data to CSV? (0 = No, 1 = Yes) (default: $export_to_csv)"
if ($userInput -ne '') { $export_to_csv = [int]$userInput }

# Prompt for accounts to check
$userInput = Read-Host "Enter comma-separated account names to check (default: all)"
if ($userInput -ne '') { $accounts_to_check = $userInput }

# Prompt for regions to check
$userInput = Read-Host "Enter comma-separated AWS regions to check (default: all)"
if ($userInput -ne '') { $regions_to_check = $userInput }

# Summary
Write-Host "`n--- Configuration in Use ---"
#Write-Host "Accounts to return       : $($num_accounts_to_return -ne 0 ? $num_accounts_to_return : 'All')"
Write-Host "Print details to terminal: $($print_details_to_terminal -ne 0 ? 'Yes' : 'No')"
Write-Host "Output table to terminal : $($output_table_to_terminal -ne 0 ? 'Yes' : 'No')"
Write-Host "Export to CSV            : $($export_to_csv -ne 0 ? 'Yes' : 'No')"
Write-Host "Accounts to check        : $($accounts_to_check -ne '' ? $accounts_to_check : 'All')"
Write-Host "Regions to check         : $($regions_to_check -ne '' ? $regions_to_check : 'All')"
Write-Host ""

# List of AWS regions to check
$desired_regions = @(
  "eu-central-1", 
  "eu-west-1", 
  "us-east-1"
)

$non_desired_regions = @( #code will check against these
  "eu-north-1", 
  "eu-west-3", 
  "eu-west-2", 
  "ca-central-1", 
  "us-west-2", 
  "us-east-2"
)

# Check if override is provided and use it
if (![string]::IsNullOrWhiteSpace($regions_to_check)) {
  $regions = $regions_to_check -split ',' | ForEach-Object { $_.Trim() }
} else {
  $regions = $desired_regions
}

if ([string]::IsNullOrWhiteSpace($regions_to_check)) {
  Write-Output "Regions to check:"
  $regions | ForEach-Object { Write-Output "- $_" }
  Write-Host ""
}


# Get all AWS profiles from .aws/config
function Extract-Profiles {
    param ([string]$filePath)
    if (Test-Path $filePath) {
        Get-Content $filePath | Select-String -Pattern "^\[profile " | ForEach-Object { $_ -replace '^\[profile (.+)\]', '$1' }
    }
}

function Print-To-Terminal {
  param ([string]$message)
  
  if($print_details_to_terminal) { Write-Output $message }
}

$configFile = "$HOME\.aws\config"

# Extract profiles starting with 'fennia'
$allProfiles = Extract-Profiles -filePath $configFile | Where-Object { $_ -like "fennia*" } | Where-Object { $_ -notmatch '-config$' } | Sort-Object -Unique

# Check if override is provided and use it
if (![string]::IsNullOrWhiteSpace($accounts_to_check)) {
  $allProfiles = $accounts_to_check -split ',' | ForEach-Object { $_.Trim() }
} 

if ($num_accounts_to_return -gt 0) {
    $profiles = $allProfiles | Select-Object -First $num_accounts_to_return
} else {
    $profiles = $allProfiles
}

# Initialize a list to store results
$results = @()


# Iterate profiles and gather access key data
Write-Output "Fetching regional usage information for $($profiles.Count) accounts"
$account_counter = 1

foreach ($profile in $profiles) {

	Write-Output "`n🔍 $account_counter). Checking profile [$profile]..."
	$account_counter++
    foreach ($region in $regions) {

		Write-Output "`n   - Checking in region >>> $region <<<"

		# Get GuardDuty status
		$guardDuty = aws guardduty list-detectors --region $region --profile $profile --output json | ConvertFrom-Json
		$guardDutyExists = $guardDuty.DetectorIds.Count -gt 0
		$guardDutyStatus = if ($guardDutyExists) { "Enabled" } else { "Not Enabled" }
		Print-To-Terminal -message "     - GuardDuty ... $guardDutyStatus"

		# Get Security Hub status
		#$securityHub = aws securityhub describe-hub --region $region --profile $profile --output json | ConvertFrom-Json
		#$securityHubExists = $securityHub.HubStatus -eq 'ENABLED'
		#$securityHubStatus = if ($securityHubExists) { "Enabled" } else { "Not Enabled" }
		#Print-To-Terminal -message "     - Security Hub ... $securityHubStatus"

		# Get AWS Config status
		$config = aws configservice describe-configuration-recorder-status --region $region --profile $profile --output json | ConvertFrom-Json
		$configExists = $config.ConfigurationRecordersStatus.Count -gt 0 -and $config.ConfigurationRecordersStatus[0].Recording
		$configStatus = if ($configExists) { "Enabled" } else { "Not Enabled" }
		Print-To-Terminal -message "     - AWS Config ... $configStatus"

		# Add result to list
		$results += [PSCustomObject]@{
		  Profile                 = $profile
		  Region                  = $region
		  guardDutyStatus         = $guardDutyStatus
		  #securityHubStatus       = $securityHubStatus
		  configStatus            = $configStatus
		}
    }
}

# Print as table
if ($output_table_to_terminal){
	$results | Format-Table -AutoSize
}

# Export to CSV
if ($export_to_csv){
	$results | Export-Csv -Path "aws_security_resource_usage.csv" -NoTypeInformation -Encoding UTF8
	Print-To-Terminal -message "`n✅ Report saved to aws_security_resource_usage.csv"
}
Write-Output ""

