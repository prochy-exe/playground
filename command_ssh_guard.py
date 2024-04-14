#!/usr/bin/env python3

from os import environ
import subprocess
executed_command = environ.get('SSH_ORIGINAL_COMMAND', "")
allowed_commands = [
  "echo hi",
  "off",
  "zzz"
]
if executed_command in allowed_commands:
  subprocess.run(executed_command, shell=True)
elif not executed_command:
  print('Please add the command after the ssh connection command')
else:
  print('Command not allowed:', executed_command)