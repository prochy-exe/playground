z#!/bin/bash

if [ -d "build" ]; then
    rm -rf "build"
fi

build_for_platform() {
    GOOS=$1
    GOARCH=$2

    if [ "$GOARCH" == "arm" ]; then
        HUMANARCH="arm"
    else if [ "$GOARCH" == "arm64" ]; then
        HUMANARCH="aarch64"
    else if [ "$GOARCH" == "amd64" ]; then
        HUMANARCH="x86_64"
    else if [ "$GOARCH" == "386" ]; then
        HUMANARCH="x86"
    else
        HUMANARCH="$GOARCH"
    fi

    if [ "$GOOS" == "windows" ]; then
        OUTPUT_NAME="pc_controller.exe"
    else
        OUTPUT_NAME="pc_controller"
    fi

    echo "Building for $GOOS $HUMANARCH..."
    GOOS=$GOOS 
    GOARCH=$GOARCH 
    go build -ldflags="-s -w" -o "build/$GOOS-$HUMANARCH/$OUTPUTNAME" pc_controller.go
}

build_for_platform "windows" "386"
build_for_platform "windows" "arm"

build_for_platform "darwin" "amd64"
build_for_platform "darwin" "386"

build_for_platform "linux" "386"
build_for_platform "linux" "arm"
