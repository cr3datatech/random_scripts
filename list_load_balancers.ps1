# Define the config and credentials file paths
$configFile = "$HOME\.aws\config"
$credentialsFile = "$HOME\.aws\credentials"

$input = Read-Host "Please enter the AWS profile name (say 'all' if you want to see LB info for all profiles)"

# Function to extract profiles from a given file
function Extract-Profiles {
    param (
        [string]$filePath
    )
    if (Test-Path $filePath) {
        Get-Content $filePath | Select-String -Pattern "^\[profile " | ForEach-Object { $_ -replace '^\[profile (.+)\]', '$1' }
    }
}

# Extract profiles from config file
$configProfiles = Extract-Profiles -filePath $configFile

# Extract profiles from credentials file
if (Test-Path $credentialsFile) {
    $credentialProfiles = Get-Content $credentialsFile | Select-String -Pattern "^\[" | ForEach-Object { $_ -replace '^\[(.+)\]', '$1' }
}

if($input -eq 'all'){
	# Combine profiles, excluding those that end with '-config'
	$allProfiles = ($configProfiles + $credentialProfiles) | Where-Object { $_ -notmatch '-config$' } | Sort-Object -Unique
} else {
	$allProfiles = $input
}



# Function to list load balancers for a specific profile
function List-LoadBalancers {
    param (
        [string]$profile
    )

    Write-Host "Profile: $profile" -ForegroundColor Cyan

    # List Classic Load Balancers (ELB)
    $elbDescriptions = aws elb describe-load-balancers --profile $profile --output json | ConvertFrom-Json
    foreach ($elb in $elbDescriptions.LoadBalancerDescriptions) {
        Write-Host "Load Balancer: $($elb.LoadBalancerName)" -ForegroundColor Yellow
        Write-Host "DNS Name: $($elb.DNSName)"
        foreach ($listener in $elb.ListenerDescriptions.Listener) {
            Write-Host "Listener: $($listener.Protocol):$($listener.LoadBalancerPort)"
        }
    }

    # List Application/Network Load Balancers (ALB/NLB)
    $elbv2LoadBalancers = aws elbv2 describe-load-balancers --profile $profile --output json | ConvertFrom-Json
    foreach ($elb in $elbv2LoadBalancers.LoadBalancers) {
        Write-Host "Load Balancer: $($elb.LoadBalancerName)" -ForegroundColor Yellow
        
        $listeners = aws elbv2 describe-listeners --load-balancer-arn $elb.LoadBalancerArn --profile $profile --output json | ConvertFrom-Json
        foreach ($listener in $listeners.Listeners) {
            Write-Host "Listener: $($listener.Protocol):$($listener.Port)"
            
            $targetGroups = aws elbv2 describe-rules --listener-arn $listener.ListenerArn --profile $profile --output json | ConvertFrom-Json
            foreach ($rule in $targetGroups.Rules) {
                foreach ($action in $rule.Actions) {
                    if ($action.Type -eq "forward") {
                        Write-Host "  Target Group Arn: $($action.TargetGroupArn)"
                        
                        # Fetch targets in the target group
                        $targets = aws elbv2 describe-target-health --target-group-arn $action.TargetGroupArn --profile $profile --output json | ConvertFrom-Json
                        foreach ($target in $targets.TargetHealthDescriptions) {
                            Write-Host "    Target: $($target.Target.Id), Port: $($target.Target.Port), Status: $($target.TargetHealth.State)"
                        }
                    }
                }
            }
        }
    }
}

# Get the profiles from the AWS config file
$profiles = Get-Content "$HOME\.aws\config" | ForEach-Object { 
    if ($_ -match '\[profile (.+?)\]') { 
        $matches[1]
    } 
}

# Loop through each profile and list load balancers
foreach ($profile in $allProfiles) {
    List-LoadBalancers -profile $profile
}

if($input -eq 'all'){
	Write-Host "Finished listing load balancers for all profiles."
} else {
	Write-Host "Finished listing load balancers for profile $input"
}