#!/bin/bash

# Define the config and credentials file paths
configFile="$HOME/.aws/config"
credentialsFile="$HOME/.aws/credentials"

# Prompt the user to enter the hosted zone ID
#$hostedZoneId = "Z05838601JZY96YSPTK4L"
read -p "Please enter the hosted zone ID: " target_hosted_zone_id

# List of AWS profiles
profiles=("fennia-audit-pd-eucentral1" "fennia-fra-network" "fennia-irl-network" "fennia-osta-laske-dev" "fennia-osta-laske-test" "fennia-osta-laske-prod" "Fennia-kompassi-sandbox-sso-cli" "fennia-kompassi-prod-sso-cli" "fennia-kompassi-test-sso-cli" "fennia-kompassi-dev-sso-cli" "fennia-kompassi-sb-eucentral1" "fennia-cgi-sandbox" "Fennia-LIIT9502-OpenText-Dev-cc-5000" "Fennia-LIIT9502-Integraatio-Sandbox-cc-5000" "Fennia-LIIT9502-Integraatio-Prod-cc-5000" "Fennia-LIIT9502-OpenText-Prod-cc-5000" "Fennia-LIIT9205-Test-cc-5000-sso-cli" "Fennia-fra-webshop-test-cc-1707" "fennia-webshop-dv-eucentral1" "fennia-webshop-pd-eucentral1" "fennia-datasecurity-sandbox" "HANKI-2394-Fennia-Pricing-KP1711-sso-cli" "fennia-fenniafi-pd-euwest1" "fennia-pricing-prod" "fennia-analytics-uat" "fennia-servicelayer-dv-eucentral1" "fennia-servicelayer-te-eucentral1" "fennia-servicelayer-pd-eucentral1" "fennia-analytics-dev-cc1711" "fennia-analytics-qa-cc1711" "Fennia-Analytics-Prod-cc1711" "fennia-data-prod-cc1711" "fenniafi-dev-KP1707" "fenniafi-KP1707" "fenniafi-test-KP1707" "fennia-pricing-dev-cc1711" "OF-Dev-KP1707" "OF-KP1707" "OF-Test-KP1707" "fennia-sagemaker-sb-euwest1" "fennia-liideri-dv-euwest1" "fennia-liideri-pd-euwest1" "fennia-mngmtiamlogin-pd-eucentral1" "fennia-mngmtlogging-pd-eucentral1" "fennia-mngmtsecurity-pd-eucentral1" "fennia-mngmtsharedcore-pd-eucentral1")

echo "Hosted Zone ID: $target_hosted_zone_id"
for profile in "${profiles[@]}"; do
  echo "Checking profile: $profile"
  
  # List hosted zones in the current profile
  hosted_zones=$(aws route53 list-hosted-zones --profile $profile --query "HostedZones[*].Id" --output text)
  
  # Check if the target hosted zone ID is in the list
  if echo "$hosted_zones" | grep -q "$target_hosted_zone_id"; then
    echo "Hosted zone $target_hosted_zone_id *** FOUND *** in profile: $profile"
    break
  else
	echo "Nope"
  fi
done
echo "Finished check ---------"