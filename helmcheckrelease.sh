#!/bin/bash

# Webhook URL for Microsoft Teams
webhook_url="https://outlook.office.com/webhook/your-webhook-url"

# Function to send message to Microsoft Teams
send_teams_notification() {
    local chart=$1
    local current_version=$2
    local latest_version=$3

    # Prepare the JSON payload
    json_payload=$(cat <<EOF
{
    "@type": "MessageCard",
    "@context": "http://schema.org/extensions",
    "themeColor": "0076D7",
    "summary": "New Helm Chart Version Available",
    "sections": [{
        "activityTitle": "Update Available for Helm Chart",
        "activitySubtitle": "A new version of $chart is available.",
        "facts": [{
            "name": "Current Version:",
            "value": "$current_version"
        }, {
            "name": "Latest Version:",
            "value": "$latest_version"
        }],
        "markdown": true
    }]
}
EOF
    )

    # Send the message using curl
    curl -H "Content-Type: application/json" -d "$json_payload" $webhook_url
}

# Update all helm repositories to ensure we have the latest charts
echo "Updating Helm repositories..."
helm repo update

# List all installed Helm releases across all namespaces
echo "Checking installed Helm charts in all namespaces..."
releases=$(helm list -A --output json)

# Parse the JSON output using jq to get the release name, chart, version, and namespace
echo "$releases" | jq -r '.[] | "\(.namespace) \(.name) \(.chart) \(.app_version)"' | while read -r namespace release chart version; do
    chart_name=$(echo "$chart" | cut -d'/' -f2)
    repo_name=$(echo "$chart" | cut -d'/' -f1)

    # Fetch the latest chart version from the repository
    latest_version=$(helm search repo $repo_name/$chart_name --versions | awk 'NR==2{print $2}')

    # Compare the current version with the latest version
    if [ "$version" != "$latest_version" ]; then
        echo "New version available for $chart_name: $latest_version (current version: $version)"
        send_teams_notification "$chart_name" "$version" "$latest_version"
    else
        echo "No update available for $chart_name (current version: $version)"
    fi
done
