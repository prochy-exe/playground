@echo off
setlocal

set "repo=%~1"
set "username=prochy-exe"

REM Check if jq is installed
where jq >nul 2>nul
if errorlevel 1 (
  echo Installing jq
  winget install jqlang.jq
)

REM Get the workflow run IDs
gh api "repos/%username%/%repo%/actions/runs" > tmp
jq -r ".workflow_runs[].id" < tmp > output
del tmp
for /f "tokens=* delims=" %%a in (output) do ( 
    gh api repos/%username%/%repo%/actions/runs/%%a -X DELETE
) 
del output
endlocal
