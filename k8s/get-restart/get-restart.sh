#!/bin/bash - 
#===============================================================================
#
#          FILE: get-restart.sh
# 
#         USAGE: ./get-restart.sh 
# 
#   DESCRIPTION: 
# 
#       OPTIONS: ---
#  REQUIREMENTS: ---
#          BUGS: ---
#         NOTES: ---
#        AUTHOR: YOUR NAME (), 
#  ORGANIZATION: 
#       CREATED: 05/09/2024 13:48
#      REVISION:  ---
#===============================================================================

set -o nounset                              # Treat unset variables as an error

interval="$1"

limite=$(date -d "$interval hour ago" +%s)

execGet(){

  pods=$(kubectl get pods -o json)

  echo "$pods" | jq -r '.items[] | select(.status.containerStatuses[].restartCount > 0) | .metadata.name + " " + (.status.containerStatuses[].lastState.terminated.finishedAt // .status.containerStatuses[].state.running.startedAt)' | while read -r pod time
  do
    seconds=$(date -d "$time" +%s)

    if (( seconds > limite ))
    then
        echo "Pod: $pod, reinicio: $time - UTC"
    fi
  done
}

execGet
