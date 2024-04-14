#!/bin/bash

allowed_commands=("printenv" "echo hi" "zzz" "off")
if [[ " ${allowed_commands[@]} " =~ " $SSH_ORIGINAL_COMMAND " ]]; then
  eval "$SSH_ORIGINAL_COMMAND"
elif [[ -z "${SSH_ORIGINAL_COMMAND}" ]]; then
  echo "Please add the command after the ssh connection command"
else
  echo "Command not allowed: $SSH_ORIGINAL_COMMAND"
fi
