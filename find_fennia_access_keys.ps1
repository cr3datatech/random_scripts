cls

# Define the config and credentials file paths
$configFile = "$HOME\.aws\config"
$results = @()

function Extract-Profiles {
    param ([string]$filePath)
    if (Test-Path $filePath) {
        Get-Content $filePath | Select-String -Pattern "^\[profile " | ForEach-Object {
            $_ -replace '^\[profile (.+)\]', '$1'
        }
    }
}

# Extract profiles starting with 'fennia'
$configProfiles = Extract-Profiles -filePath $configFile | Where-Object { $_ -like "fennia*" }# | Select-Object -First 11

# Remove profiles ending with '-config'
$accounts = $configProfiles | Where-Object { $_ -notmatch '-config$' } | Sort-Object -Unique

# Initialize results array
$results = @()

# Iterate profiles and gather access key data
Write-Output "Fetching IAM users and access key information for $($accounts.Count) accounts"
$account_counter = 1

foreach ($account in $accounts) {
    $users = aws iam list-users --profile $account --query 'Users[*].UserName' --output json | ConvertFrom-Json

    Write-Output "$account_counter). $account ($($users.Count))"
    $account_counter++

    if (!$users -or $users.Count -eq 0) {
        # Add empty row for account with no users
        $results += [pscustomobject]@{
            Account                     = $account
            Username                    = ""
            'Access Key ID'             = ""
            'Creation Date'             = ""
            'Last Access (days ago)'    = ""
            Active                      = ""
            'Key Age (days)'            = ""
            'Last Used Service'         = ""
            'Last Used Region'          = ""
        }
    }
    else {
        foreach ($username in $users) {
            
            $accessKeys = @(
                aws iam list-access-keys --user-name $username --profile $account --query 'AccessKeyMetadata[*].[AccessKeyId,CreateDate,Status]' --output json  | ConvertFrom-Json
            )

            Write-Output "    - username: $username ($($accessKeys.Count))"

            if (!$accessKeys -or $accessKeys.Count -eq 0) {
                # Add empty row for account with a user but no access keys
                $results += [pscustomobject]@{
                    Account                     = $account
                    Username                    = $username
                    'Access Key ID'             = ""
                    'Creation Date'             = ""
                    'Last Access (days ago)'    = ""
                    Active                      = ""
                    'Key Age (days)'            = ""
                    'Last Used Service'         = ""
                    'Last Used Region'          = ""
                }
            }
            else {
                foreach ($key in $accessKeys){
                    $accessKeyId = $key[0]
                    $createDate  = $key[1]
                    $status      = $key[2]
                    
                    $lastUsedDate = ""
                    $serviceName = ""
                    $lastUsedRegion = ""

                    try {
                        $lastUsed = aws iam get-access-key-last-used --access-key-id $accessKeyId --profile $account --query 'AccessKeyLastUsed.[LastUsedDate,ServiceName,Region]' --output json | ConvertFrom-Json
                        if ($lastUsed.Count -ge 2) {
                            $lastUsedDate = [datetime]::ParseExact($lastUsed[0], "MM/dd/yyyy HH:mm:ss", $null)
                            $lastUsedDate = (Get-Date) - $lastUsedDate
                            $lastUsedDate = $lastUsedDate.Days

                            $serviceName = $lastUsed[1]
                            $lastUsedRegion = $lastUsed[2]
                        }
                    } catch {
                        # Ignore errors for keys never used
                    }
        
                    $isActive = if ($status -eq "Active") { "Yes" } else { "No" }
        
                    try {
                        $cDate = [datetime]::ParseExact($createDate, "MM/dd/yyyy HH:mm:ss", $null)
                        $keyAge = (Get-Date) - $cDate
                        $keyAge = $keyAge.Days
                    } catch {
                        $keyAge = ""
                    }
            
                    # Add full row for account with a user and one access keys
                    $results += [pscustomobject]@{
                        Account                     = $account
                        Username                    = $username
                        'Access Key ID'             = $accessKeyId
                        'Creation Date'             = $createDate
                        'Last Access (days ago)'    = $lastUsedDate
                        Active                      = $isActive
                        'Key Age (days)'            = $keyAge
                        'Last Used Service'         = $serviceName
                        'Last Used Region'          = $lastUsedRegion
                    }
                    
                }
            }
        }
        
    }
}


# Print as table
$results | Format-Table -AutoSize

# If saving to CSV
Write-Output ">>> Outputting to CSV file access_keys.csv"
$results | Export-Csv -Path "access_keys.csv" -NoTypeInformation

