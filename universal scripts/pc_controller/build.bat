@echo off

if exist "build" (
    rmdir /S /Q "build"
)

call :build_for_platform windows 386
call :build_for_platform windows arm

call :build_for_platform darwin amd64
call :build_for_platform darwin arm64

call :build_for_platform linux 386
call :build_for_platform linux arm
exit /b

:build_for_platform
setlocal
set GOOS=%1
set GOARCH=%2

if "%GOARCH%"=="arm" (
    set HUMANARCH=arm
) else if "%GOARCH%"=="arm64" (
    set HUMANARCH=aarch64
) else if "%GOARCH%"=="amd64" (
    set HUMANARCH=x86_64
) else if "%GOARCH%"=="386" (
    set HUMANARCH=x86
) else (
    set HUMANARCH=%GOARCH%
)

if "%GOOS%"=="windows" (
    set OUTPUT_NAME=pc_controller.exe
) else (
    set OUTPUT_NAME=pc_controller
)
echo Building for %GOOS% %HUMANARCH%...
go build -ldflags="-s -w" -o build\%GOOS%-%HUMANARCH%\%OUTPUTNAME% pc_controller.go
endlocal