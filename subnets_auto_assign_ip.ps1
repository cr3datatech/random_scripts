# Function to extract all AWS profiles from .aws/config
cls
$print_details_to_terminal = 0
$output_table_to_terminal = 1
$num_accounts_to_return = 0
$export_to_csv = 1

$results = @()

$regions = @( #code will check against these
  "eu-central-1", 
  "eu-west-1", 
  "us-east-1",
  "eu-north-1", 
  "eu-west-3", 
  "eu-west-2", 
  "ca-central-1", 
  "us-west-2", 
  "us-east-2"
)

# Function to extract all AWS profiles from .aws/config
function Extract-Profiles {
  param ([string]$filePath)
  if (Test-Path $filePath) {
      Get-Content $filePath | Select-String -Pattern "^\[profile " | ForEach-Object { $_ -replace '^\[profile (.+)\]', '$1' }
  }
}

# Function to print messages to the terminal
function Print-To-Terminal {
  param ([string]$message)

  if($print_details_to_terminal) { Write-Output $message }
}

$configFile = "$HOME\.aws\config"

# Extract profiles starting with 'fennia'
$allProfiles = Extract-Profiles -filePath $configFile | Where-Object { $_ -like "fennia*" } | Where-Object { $_ -notmatch '-config$' } | Sort-Object -Unique

if ($num_accounts_to_return -gt 0) {
  $profiles = $allProfiles | Select-Object -First $num_accounts_to_return
} else {
  $profiles = $allProfiles
}

# Loop through each profile to check subnets
Write-Output "Fetching subnet auto assign IP for $($profiles.Count) accounts"
$account_counter = 1
$find_count = 0

foreach ($profile in $profiles) {
  $find_count = 0
  Write-Output "`n🔍 $account_counter). Checking profile [$profile]..."
  $account_counter++

  foreach ($region in $regions) {
    Write-Output "        - Checking in region >>> $region <<<"

    # Get the raw JSON output of the subnets
    $subnetsRaw = aws ec2 describe-subnets --profile $profile --region $region --output json

    # Convert JSON string to a PowerShell object
    $subnets = $subnetsRaw | ConvertFrom-Json

    # Loop through each subnet and format output
    foreach ($subnet in $subnets.Subnets) {
      if($subnet.MapPublicIpOnLaunch){
        $find_count++

        $subnetId = $subnet.SubnetId
        $subnetAZ = $subnet.AvailabilityZone
        $vpcId = $subnet.VpcId

        Print-To-Terminal -m "Checking Instances"
        $instances = aws ec2 describe-instances --profile $profile --region $region --filters "Name=subnet-id,Values=$subnetId" --query "Reservations[*].Instances[*].InstanceId" --output text
        $instance_count = @($instances).length        

        Print-To-Terminal -m "Checking elbs"
        $elbs = aws elb describe-load-balancers --profile $profile --region $region --query "LoadBalancerDescriptions[?Subnets=='$subnetId'].LoadBalancerName" --output text
        $elb_count = @($elbs).length  

        Print-To-Terminal -m "Checking rdss"
        $rdss = aws rds describe-db-instances --profile $profile --region $region --query "DBInstances[?DBSubnetGroup.Subnets[?SubnetIdentifier=='$subnetId']].DBInstanceIdentifier" --output text
        $rds_count = @($rdss).length  

        Print-To-Terminal -m "Checking nats"
        $nats = aws ec2 describe-nat-gateways --profile $profile --region $region --filter "Name=subnet-id,Values=$subnetId" --query "NatGateways[*].NatGatewayId" --output text
        $nat_count = @($nats).length  

        Print-To-Terminal -m "Checking rtbls"
        $rtbls = aws ec2 describe-route-tables --profile $profile --region $region --query "RouteTables[?Associations[?SubnetId=='$subnetId']].RouteTableId" --output text
        $rtbl_count = @($rtbls).length

        Print-To-Terminal -m "Checking sgs"
        $sgs = aws ec2 describe-security-groups --profile $profile --region $region --query "SecurityGroups[?VpcId=='$vpcId'].GroupId" --output text
        $sg_count = @($sgs).length

        Print-To-Terminal -m "Checking cwlogs"
        $cwlogs = aws cloudwatch describe-alarms --profile $profile --region $region --query "MetricAlarms[?Namespace=='AWS/EC2' && Dimensions[?Name=='SubnetId' && Value=='$subnetId']].AlarmName" --output text
        $cwlog_count = @($cwlogs).length

        Print-To-Terminal -m "Checking datas"
        $datas = aws ec2 describe-volumes --profile $profile --region $region --filters "Name=availability-zone,Values=$subnetAZ" --query "Volumes[*].VolumeId" --output text
        $data_count = @($datas).length

        $results += [PSCustomObject]@{
          Profile                 = $profile
          Region                  = $region
          SubnetId                = $subnet.SubnetId
          VpcId                   = $subnet.VpcId
          CidrBlock               = $subnet.CidrBlock
          MapPublicIpOnLaunch     = $subnet.MapPublicIpOnLaunch
          Instances               = $instance_count
          ELBs                    = $elb_count
          RDSs                    = $rds_count
          NATs                    = $nat_count
          Route_Tables            = $rtbl_count
          Security_Groups         = $sg_count
          CloudWatch_Logs         = $cwlog_count
          Volumes            = $data_count
        }
      }
    }
  }

  Write-Output "`n        >>> $find_count subnets found <<<`n"

}

if ($output_table_to_terminal){
  $array_size = @($results).length
  Write-Output "`n>>> $array_size subnets found <<<`n"
  $results | Format-Table -AutoSize
}

if ($export_to_csv){
  $results | Export-Csv -Path "aws_subnet_public_ip_default.csv" -NoTypeInformation -Encoding UTF8
  Print-To-Terminal -message "`n✅ Report saved to aws_resource_usage.csv"
}
