#!/bin/sh

repo=$1
username="prochy-exe"

# Check if jq is installed
if ! command -v jq &> /dev/null; then
    echo "jq is not installed. Installing jq."
    if [ -f /etc/os-release ] && grep -q "ID=debian" /etc/os-release; then
        sudo apt-get install jq -y;
    else
        echo "Not a Debian system, please install jq manually."
        exit
    fi
fi

gh api repos/$username/$repo/actions/runs | \
  jq '.workflow_runs[].id' | \
  xargs -n1 -I % gh api repos/$username/$repo/actions/runs/% -X DELETE