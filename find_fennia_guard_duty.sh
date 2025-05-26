#!/bin/bash
clear
echo "Checking if GuardDuty is ENABLED for the list of profiles in this file."

# Define the config and credentials file paths
configFile="$HOME/.aws/config"
credentialsFile="$HOME/.aws/credentials"

# List of AWS profiles
profiles=("fennia-analytics-dv-euwest1" "fennia-analytics-pd-euwest1" "fennia-analytics-qa-euwest1" "fennia-audit-pd-eucentral1" "fennia-cgi-sb-euwest1-eucentral1" "fennia-data-pd-euwest1" "fennia-data-tl-euwest1" "fennia-datasecurity-sb-euwest1" "fennia-fenniafi-dv-euwest1" "fennia-fenniafi-pd-euwest1" "fennia-fenniafi-te-euwest1" "fennia-integration-pd-eucentral1" "fennia-integration-sb-eucentral1" "fennia-kompassi-dv-eucentral1" "fennia-kompassi-pd-eucentral1" "fennia-kompassi-sb-eucentral1" "fennia-kompassi-te-eucentral1" "fennia-laske-osta-dv-eucentral1" "fennia-laske-osta-pd-eucentral1" "fennia-laske-osta-te-eucentral1" "fennia-liideri-dv-euwest1" "fennia-liideri-pd-euwest1" "fennia-liit-te-eucentral1" "fennia-logarchive-pd-eucentral1" "fennia-master-pd-eucentral1" "fennia-mngmtiamlogin-pd-eucentral1" "fennia-mngmtlogging-pd-eucentral1" "fennia-mngmtsharedcore-pd-eucentral1" "fennia-netso-dv-eucentral1" "fennia-network-eucentral1" "fennia-network-euwest1" "fennia-opentext-dv-eucentral1" "fennia-opentext-pd-eucentral1" "fennia-patu-sandbox-sb-eucentral1" "fennia-pricing-dv-euwest1" "fennia-pricing-pd-euwest1" "fennia-sagemaker-sb-euwest1" "fennia-servicelayer-dv-eucentral1" "fennia-servicelayer-pd-eucentral1" "fennia-servicelayer-te-eucentral1" "fennia-webshop-dv-eucentral1" "fennia-webshop-pd-eucentral1" "fennia-webshop-te-eucentral1" "omafennia-dv-euwest1" "omafennia-pd-euwest1" "omafennia-te-euwest1")

for profile in "${profiles[@]}"; do
    #echo "Checking GuardDuty for profile: $profile"
    
    # Get the current region for the profile
    region=$(aws configure get region --profile "$profile")

    # Check if GuardDuty is enabled by describing the detector
    detector_id=$(aws guardduty list-detectors --profile "$profile" --region "$region" --query 'DetectorIds[0]' --output text)

    if [[ "$detector_id" == "None" ]]; then
        echo "❌ GuardDuty is NOT enabled for profile: $profile"
    else
        echo "✅ GuardDuty is ENABLED for profile: $profile (Detector ID: $detector_id)"
    fi
done
echo "Finished check ---------"