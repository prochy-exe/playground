@echo off

if "%SSH_ORIGINAL_COMMAND%"=="echo hi" goto run_command
if "%SSH_ORIGINAL_COMMAND%"=="off" goto run_command
if "%SSH_ORIGINAL_COMMAND%"=="zzz" goto run_command
if "%SSH_ORIGINAL_COMMAND%"=="" goto empty_command

echo Command not allowed: "%SSH_ORIGINAL_COMMAND%"
goto :common_exit

:run_command
%SSH_ORIGINAL_COMMAND%
goto common_exit

:empty_command
echo Please add the command after the ssh connection command
goto common_exit

:common_exit
exit