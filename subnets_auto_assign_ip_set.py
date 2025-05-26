import boto3
import sys

# Function to print messages to the terminal
def print_to_terminal(message):
    print(message)

# Get profile and region from arguments or ask user for input
arg_my_profile = sys.argv[1] if len(sys.argv) > 1 else None
arg_region = sys.argv[2] if len(sys.argv) > 2 else None

# Ask the user for the AWS profile
my_profile = input(f"Please enter the AWS profile name ({arg_my_profile}): ") or arg_my_profile

# Ask the user for the region
region = input(f"Please enter the AWS region ({arg_region}): ") or arg_region

# Set up the boto3 session
session = boto3.Session(profile_name=my_profile, region_name=region)
ec2 = session.client('ec2')

# Get list of subnets
response = ec2.describe_subnets()
subnet_ids = [subnet['SubnetId'] for subnet in response['Subnets']]

# Print the list of subnet IDs
print_to_terminal("\nList of subnet IDs:")
print(subnet_ids)

# Loop through each subnet ID in the list
for subnet_id in subnet_ids:
    # Ask the user if they want to run the command for this subnet
    response = input(f"\n🔍 Do you want to set 'Auto-assign public IPv4 address' to No for subnet {subnet_id}? (Y/N): ").lower()

    # Check if the response is 'Y' or 'y' (case-insensitive)
    if response in ['y', 'yes']:
        # Run the AWS command to modify the subnet attribute
        print_to_terminal(f"Setting 'Auto-assign public IPv4 address' to No for subnet: {subnet_id}")
        
        ec2.modify_subnet_attribute(
            SubnetId=subnet_id,
            MapPublicIpOnLaunch={'Value': False}
        )

        print_to_terminal(f"Successfully updated subnet: {subnet_id}")
    else:
        print_to_terminal(f"Skipping subnet: {subnet_id}")
