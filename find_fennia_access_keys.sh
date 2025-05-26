#!/bin/bash
clear

# Check if jq is installed
if ! command -v jq &> /dev/null; then
    echo "jq is required but not installed. Please install jq and try again."
    exit 1
fi

# List of AWS profiles
accounts=("Fennia-LIIT9502-OpenText-Prod-cc-5000" "Fennia-LIIT9502-OpenText-Dev-cc-5000")

# Function to get access key information
get_access_keys() {
    local profile=$1
    local username=$2
	echo "  Profile: $profile"
	echo "  User name: $username"
    access_keys=$(aws iam list-access-keys --user-name "$username" --profile "$profile" --query 'AccessKeyMetadata[*].[AccessKeyId,CreateDate]' --output json)
    
    echo "$access_keys" | jq -c '.[]' | while read -r key; do
        access_key_id=$(echo "$key" | jq -r '.[0]')
        create_date=$(echo "$key" | jq -r '.[1]')
        last_used=$(aws iam get-access-key-last-used --access-key-id "$access_key_id" --profile "$profile" --query 'AccessKeyLastUsed.[LastUsedDate,ServiceName]' --output json)
        
        last_used_date=$(echo "$last_used" | jq -r '.[0]')
        service_name=$(echo "$last_used" | jq -r '.[1]')
        
        echo "  Access Key ID: $access_key_id"
        echo "  Creation Date: $create_date"
        echo "  Last Access Date: $last_used_date"
        echo "  Last Used Service: $service_name"
        echo "--------------------------------------"
    done
}

# Iterate over each profile and list IAM users with their access key information
for account in "${accounts[@]}"; do
    echo "Fetching IAM users and access key information for account: $account"
    
    users=$(aws iam list-users --profile "$account" --query 'Users[*].UserName' --output json)
    
    if [ "$users" == "[]" ]; then
        echo "No IAM users found for account: $account."
    else
        echo "IAM users for account: $account"
        echo "$users" | jq -r '.[]' | while read -r username; do
            echo "User: $username"
            get_access_keys "$account" "$username"
        done
    fi
done
