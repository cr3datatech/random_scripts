# Function to extract all AWS profiles from .aws/config
cls

$argMyProfile = $args[0]
$argRegion = $args[1]

# Ask the user for the AWS profile
$myProfile = Read-Host "Please enter the AWS profile name ($argMyProfile)"

# Ask the user for the region
$region = Read-Host "Please enter the AWS region ($argRegion)"

if($myProfile -eq ""){
  $myProfile = $argMyProfile
}

if($region -eq ""){
  $region = $argRegion
}

# Function to print messages to the terminal
function Print-To-Terminal {
  param ([string]$message)
  Write-Output $message
}

$subnets = aws ec2 describe-subnets --profile $myProfile --region $region --query "Subnets[*].SubnetId" --output text
# Split the result into an array (each subnet ID will be a separate element)
$subnetIds = $subnets.Split()

# Print the array of subnet IDs
Print-To-Terminal -m "`nList of subnet IDs:"
$subnetIds

# Loop through each Subnet ID in the list
foreach ($subnetId in $subnetIds) {
  # Ask the user if they want to run the command for this subnet
  $response = Read-Host "`n🔍 Do you want to set 'Auto-assign public IPv4 address' to No for subnet $subnetId ? (Y/N)"

  # Check if the response is 'Y' or 'y' (case-insensitive)
  if ($response -match "^[Yy]$") {
    # Run the AWS command to modify the subnet attribute
    Print-To-Terminal -m "Setting 'Auto-assign public IPv4 address' to No for subnet: $subnetId"
    aws ec2 modify-subnet-attribute --profile $myProfile --region $region --subnet-id $subnetId --no-map-public-ip-on-launch --output text
    Print-To-Terminal -m "Successfully updated subnet: $subnetId"
  } else {
      Print-To-Terminal -m "Skipping subnet: $subnetId"
  } 
}
