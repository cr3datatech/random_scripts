cls

# Default SETTINGS
$num_accounts_to_return = 0
$print_details_to_terminal = 0 
$output_table_to_terminal = 0
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
  #"eu-central-1", 
  #"eu-west-1", 
  #"us-east-1",
  "eu-north-1", 
  #"eu-west-3", 
  "eu-west-2", 
  "ca-central-1", 
  "us-west-2", 
  "us-east-2"
)

# Check if override is provided and use it
if (![string]::IsNullOrWhiteSpace($regions_to_check)) {
  $regions = $regions_to_check -split ',' | ForEach-Object { $_.Trim() }
} else {
  $regions = $non_desired_regions
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

      # Check EC2 instances
      $ec2 = aws ec2 describe-instances --region $region --profile $profile --query 'Reservations[*].Instances[*].InstanceId' --output json | ConvertFrom-Json
      $ec2Exists = $ec2.Count -gt 0
      $ec2Count = ($ec2 | ForEach-Object { $_.Count }) | Measure-Object -Sum | Select-Object -ExpandProperty Sum
      $ec2Count = if ($ec2Count) { $ec2Count } else { 0 }
      Print-To-Terminal -message "     - EC2 instances ... $ec2Count"

      # --- EBS ---
      $ebsVolumes = aws ec2 describe-volumes --region $region --profile $profile `
      --query "Volumes[?State=='in-use' || State=='available'].VolumeId" --output json | ConvertFrom-Json

      $ebsCount = if ($ebsVolumes) { $ebsVolumes.Count } else { 0 }
      $ebsExists = $ebsCount -gt 0
      Print-To-Terminal -message "     - EBS volume count ... $ebsCount"


      # Check S3 buckets (Global service - only check once per profile)
      if ($region -eq 'us-east-1') {
          $s3 = aws s3api list-buckets --profile $profile --output json | ConvertFrom-Json
          $s3Exists = $s3.Buckets.Count -gt 0
          $s3Count = $s3.Buckets.Count
      } else {
          $s3Count = 0
      }
      $s3Exists = $s3Count -gt 0
      Print-To-Terminal -message "     - S3 Buckets ... $s3Count"

      # Check Lambda functions
      $lambda = aws lambda list-functions --region $region --profile $profile --query 'Functions[*].FunctionName' --output json | ConvertFrom-Json
      $lambdaCount = if ($lambda) { $lambda.Count } else { 0 }
      #Print-To-Terminal -message "     - Lambdas... $lambdaCount"

      $filteredLambda = $lambda | Where-Object { $_ -match "controltower" }
      $filteredLambdaCount = if ($filteredLambda) { $filteredLambda.Count } else { 0 }
      #Print-To-Terminal -message "     - ControlTower Lambdas... $filteredLambdaCount"

      $nonCTLambdasCount = if ($lambda) { $lambdaCount - $filteredLambdaCount } else { 0 }
      $lambdaExists = $nonCTLambdasCount -gt 0
      Print-To-Terminal -message "     - Lambda count (excluding ControlTower) ... $nonCTLambdasCount"        

      # --- RDS ---
      $rdsInstances = aws rds describe-db-instances --region $region --profile $profile --query "DBInstances[?DBInstanceStatus=='available'].DBInstanceIdentifier" --output json | ConvertFrom-Json
      $rdsRunning = $rdsInstances.Count -gt 0
      $rdsCount = if( $rdsInstances ) { $rdsInstances.Count } else { 0 }
      Print-To-Terminal -message "     - RDS count ... $rdsCount"

      # --- DynamoDB (excluding terraform-locks) ---
      $dynamoTablesRaw = aws dynamodb list-tables --region $region --profile $profile --output json | ConvertFrom-Json
      $dynamoTables = $dynamoTablesRaw.TableNames | Where-Object { $_ -notlike '*terraform-locks*' }

      $dynamoCount = if ($dynamoTables) { $dynamoTables.Count } else { 0 }
      $dynamoExists = $dynamoCount -gt 0
      Print-To-Terminal -message "     - DynamoDB table count (excluding 'terraform-locks') ... $dynamoCount"


      # --- Redis (ElastiCache) ---
      $redisClusters = aws elasticache describe-replication-groups --region $region --profile $profile `
      --query "ReplicationGroups[?Status=='available'].ReplicationGroupId" --output json | ConvertFrom-Json

      $redisCount = if ($redisClusters) { $redisClusters.Count } else { 0 }
      $redisAvailable = $redisCount -gt 0
      Print-To-Terminal -message "     - Redis cluster count ... $redisCount"

      # --- ECS ---
      $ecsClustersResponse = aws ecs list-clusters --region $region --profile $profile --output json | ConvertFrom-Json
      $ecsClusters = $ecsClustersResponse.clusterArns
      $ecsRunning = $ecsClusters.Count -gt 0
      $ecsCount = if( $ecsClusters ) { $ecsRunning.Count } else { 0 }
      Print-To-Terminal -message "     - ECS count ... $ecsCount"

      # --- CloudFormation ---
      $stacks = aws cloudformation list-stacks --region $region --profile $profile `
      --query "StackSummaries[?StackStatus=='CREATE_COMPLETE' || StackStatus=='UPDATE_COMPLETE'].StackName" --output json | ConvertFrom-Json

      # Filter out stacks that contain 'AWSControlTower', or 'awsconfig'
      $filteredStacks = $stacks | Where-Object {
        $_ -notmatch 'AWSControlTower' -and
        $_ -notmatch 'AWSCloudFormation' -and
        $_ -notmatch 'awsconfig' -and
        $_ -notmatch 'AWSCloudWatch'
      }

      $cfActive = $filteredStacks.Count -gt 0
      $cfCount = if ($filteredStacks) { $filteredStacks.Count } else { 0 }

      Print-To-Terminal -message "     - CloudFormation count (excluding AWSControlTower, AWSCloudFormation, awsconfig, AWSCloudWatch) ... $cfCount"

      # --- EKS ---
      $eksClustersResponse  = aws eks list-clusters --region $region --profile $profile --output json | ConvertFrom-Json
      $eksClusters = $eksClustersResponse.clusters
      $eksRunning = $eksClusters.Count -gt 0
      $eksCount = if( $eksClusters ) { $eksClusters.Count } else { 0 }
      Print-To-Terminal -message "     - EKS count ... $eksCount"

      # --- VPC ---
      $vpcs = aws ec2 describe-vpcs --region $region --profile $profile --query "Vpcs[*].VpcId" --output json | ConvertFrom-Json
      $vpcExists = $vpcs.Count -gt 0
      $vpcCount = if( $vpcs ) { $vpcs.Count } else { 0 }
      Print-To-Terminal -message "     - VPC count (includes default VPCs) ... $vpcCount"

      # --- Internet Gateways (IGW) ---
      $igws = aws ec2 describe-internet-gateways --region $region --profile $profile `
      --query "InternetGateways[*].InternetGatewayId" --output json | ConvertFrom-Json

      $igwCount = if ($igws) { $igws.Count } else { 0 }
      $igwExists = $igwCount -gt 0
      Print-To-Terminal -message "     - Internet Gateway count ... $igwCount"

      # --- NAT Gateways ---
      $natGateways = aws ec2 describe-nat-gateways --region $region --profile $profile `
      --query "NatGateways[?State=='available'].NatGatewayId" --output json | ConvertFrom-Json

      $natCount = if ($natGateways) { $natGateways.Count } else { 0 }
      $natExists = $natCount -gt 0
      Print-To-Terminal -message "     - NAT Gateway count ... $natCount"

      # --- CloudWatch Alarms ---
      $alarms = aws cloudwatch describe-alarms --region $region --profile $profile --query "MetricAlarms[*].AlarmName" --output json | ConvertFrom-Json
      # Filter out alarms that contain 'terraform-locks'
      $filteredAlarms = $alarms | Where-Object { $_ -notmatch 'terraform-locks' }
      $alarmsExist = $filteredAlarms.Count -gt 0
      $alarmsCount = if( $filteredAlarms ) { $filteredAlarms.Count } else { 0 }
      Print-To-Terminal -message "     - CloudWatch Alarms count (excluding terraform-locks) ... $alarmsCount"

      # --- Overall Activity Flag ---
      $regionActive = $ec2Exists -or $s3Exists -or $lambdaExists -or $rdsRunning -or $ecsRunning -or $cfActive -or $eksRunning -or $vpcExists -or $alarmsExist -or $ebsExists -or $dynamoExists -or $redisAvailable -or $igwExists -or $natExists
      # Print-To-Terminal -message "     - Region is active --> $regionActive"
      Write-Output "     - Region is active --> $regionActive"

      # Add result to list
      $results += [PSCustomObject]@{
          Profile                 = $profile
          Region                  = $region
          EC2_Count               = $ec2Count
          EBS_count               = $ebsCount
          S3_Count                = $s3Count
          Lambda_Count            = $nonCTLambdasCount
          RDS_Count               = $rdsCount
          DynamoDB_count          = $dynamoCount
          Redis_count             = $redisCount
          ECS_Count               = $ecsCount
          CloudFormation_Count    = $cfCount
          EKS_Clusters_Count      = $eksCount
          VPC_Count               = $vpcCount
          IGW_count               = $igwCount
          NAT_count               = $natCount
          CloudWatch_Alarms_Count = $alarmsCount
          Activity_Detected       = $regionActive
      }
    }
}

# Print as table
if ($output_table_to_terminal){
  $results | Format-Table -AutoSize
}

# Export to CSV
if ($export_to_csv){
  $results | Export-Csv -Path "aws_resource_usage.csv" -NoTypeInformation -Encoding UTF8
  Print-To-Terminal -message "`n✅ Report saved to aws_resource_usage.csv"
}
Write-Output ""

