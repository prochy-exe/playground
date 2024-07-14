#!/bin/sh

repo=$1
username="Pr0chy"
if [ $(dpkg-query -W -f='${Status}' jq 2>/dev/null | grep -c "ok installed") -eq 0 ];
then
  echo "Installing jQ"
  sudo apt-get install jq -y;
fi
gh api repos/$username/$repo/actions/runs | \
  jq '.workflow_runs[].id' | \
  xargs -n1 -I % gh api repos/$username/$repo/actions/runs/% -X DELETE