@echo off

if exist "build" (
    rmdir /S /Q "build"
)

call :build_for_platform windows 386
call :build_for_platform windows arm
call :build_for_platform linux 386
call :build_for_platform linux arm

exit /b

:build_for_platform
setlocal
set GOOS=%1
set GOARCH=%2

if "%GOARCH%"=="arm" (
    set HUMANARCH=arm
) else if "%GOARCH%"=="386" (
    set HUMANARCH=x86
) else (
    set HUMANARCH=%GOARCH%
)

if "%GOOS%"=="windows" (
    set OUTPUTNAME=controlifywatcher.exe
) else (
    set OUTPUTNAME=controlifywatcher
)

echo Building for %GOOS% %HUMANARCH%...
go build -ldflags="-s -w -H=windowsgui" -o build\%GOOS%-%HUMANARCH%\%OUTPUTNAME% controlifywatcher.go
endlocal