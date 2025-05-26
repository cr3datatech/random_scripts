cls
# Define the config and credentials file paths
$configFile = "$HOME\.aws\config"

function Extract-Profiles {
    param (
        [string]$filePath
    )
    if (Test-Path $filePath) {
        Get-Content $filePath | Select-String -Pattern "^\[profile " | ForEach-Object { $_ -replace '^\[profile (.+)\]', '$1' }
    }
}

# Extract profiles from config file
#$configProfiles = Extract-Profiles -filePath $configFile
$configProfiles = Extract-Profiles -filePath $configFile | Where-Object { $_ -like "fennia*" } | Select-Object -First 5
#Write-Output $configProfiles

# Combine profiles, excluding those that end with '-config'
$accounts = ($configProfiles) | Where-Object { $_ -notmatch '-config$' } | Sort-Object -Unique

# List of AWS profiles
#$accounts = @("Fennia-LIIT9502-OpenText-Prod-cc-5000", "Fennia-LIIT9502-OpenText-Dev-cc-5000")

# Function to get access key information
function Get-AccessKeys {
    param (
        [string]$profile,
        [string]$username
    )

	$accessKeys = @(
        aws iam list-access-keys --user-name $username --profile $profile --query 'AccessKeyMetadata[*].[AccessKeyId,CreateDate,Status]' --output json  | ConvertFrom-Json
		#aws iam list-access-keys --user-name $username --profile $profile --query 'AccessKeyMetadata[*].[AccessKeyId,CreateDate]' --output json | ConvertFrom-Json
	)

	foreach ($key in $accessKeys) {
		$accessKeyId = $key[0]
        $createDate = $key[1]
        $status = $key[2]

        #Write-Output "  Key: $key"
		
		Write-Output "  Access Key ID: $accessKeyId"
        Write-Output "  Creation Date: $createDate"
		
		$lastUsed = aws iam get-access-key-last-used --access-key-id $accessKeyId --profile $profile --query 'AccessKeyLastUsed.[LastUsedDate,ServiceName]' --output json | ConvertFrom-Json
        
		if($lastUsed.Count -ne 0){
			$lastUsedDate = $lastUsed[0]
			$serviceName = $lastUsed[1]
			Write-Output "  Last Access Date: $lastUsedDate"

            # Is the key active?
            $isActive = if ($status -eq "Active") { "Yes" } else { "No" }
            Write-Output "  Is Key Active: $isActive"
            
            # Parse the date using the known format
            $cDate = [datetime]::ParseExact($createDate, "MM/dd/yyyy HH:mm:ss", $null)

            # Calculate key age
            $keyAge = (Get-Date) - $cDate
            Write-Output "  Key Age (days): $($keyAge.Days)"

			Write-Output "  Last Used Service: $serviceName"
		}
	}
}

# Iterate over each profile and list IAM users with their access key information
foreach ($account in $accounts) {
    Write-Output "Fetching IAM users and access key information for account: $account"
    
    $users = aws iam list-users --profile $account --query 'Users[*].UserName' --output json | ConvertFrom-Json
    
    if ($users.Count -eq 0) {
        Write-Output "No IAM users found for account: $account."
    } else {
        Write-Output "IAM users for account: $account"
        foreach ($username in $users) {
            #Write-Output "Account: $account"
			Write-Output "----- Username: $username -----"
            Get-AccessKeys -profile $account -username $username
        }
    }
	Write-Output "--------------------------------------"
}
