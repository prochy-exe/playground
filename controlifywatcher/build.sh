#!/bin/bash

if [ -d "build" ]; then
    rm -rf "build"
fi

build_for_platform() {
    GOOS=$1
    GOARCH=$2

    if [ "$GOARCH" == "arm" ]; then
        HUMANARCH="arm"
    elif [ "$GOARCH" == "386" ]; then
        HUMANARCH="x86"
    else
        HUMANARCH="$GOARCH"
    fi

    if [ "$GOOS" == "windows" ]; then
        OUTPUTNAME="controlifywatcher.exe"
    else
        OUTPUTNAME="controlifywatcher"
    fi

    echo "Building for $GOOS $HUMANARCH..."
    GOOS=$GOOS 
    GOARCH=$GOARCH 
    go build -ldflags="-s -w" -o "build/$GOOS-$HUMANARCH/$OUTPUTNAME" controlifywatcher.go
}

build_for_platform "windows" "386"
build_for_platform "windows" "arm"
build_for_platform "linux" "386"
build_for_platform "linux" "arm"
