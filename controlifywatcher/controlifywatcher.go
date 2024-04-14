//go:build windows

package main

import (
	"context"
	_ "controlifywatcher/assets"
	"controlifywatcher/utils"
	_ "embed"
	"fmt"
	"os"
	"os/signal"
	"path/filepath"
	"runtime"
	"syscall"
	"time"

	"fyne.io/systray"
	"github.com/gen2brain/beeep"
)

//go:embed assets/icon.ico
var windowsIconData []byte

//go:embed assets/icon.png
var linuxIconData []byte

var (
	controlifyRunning bool
	controlifyName    string
	iconData          []byte
	beeepIconName     string
	noTray            bool
	cliControlify     bool
	imgPath           string
	controlifyArgs    string
	exePath           = func() string { // Get the directory of the executable, even if it's a symlink
		execPath, err := os.Executable()
		if err != nil {
			return filepath.Dir(func() string { p, _ := os.Executable(); return p }())
		}

		resolvedPath, err := filepath.EvalSymlinks(execPath)
		if err != nil {
			return filepath.Dir(func() string { p, _ := os.Executable(); return p }())
		}

		dir := filepath.Dir(resolvedPath)
		return dir
	}()
)

func createTempImage() (string, error) {
	tmpDir := os.TempDir()
	tmpFilePath := filepath.Join(tmpDir, beeepIconName)
	err := os.WriteFile(tmpFilePath, iconData, 0644)
	if err != nil {
		return "", fmt.Errorf("error writing to temporary file: %v", err)
	}
	return tmpFilePath, nil
}

func main() {
	if runtime.GOOS == "windows" {
		iconData = windowsIconData
		beeepIconName = "icon.ico"
	} else {
		iconData = linuxIconData
		beeepIconName = "icon.png"
	}

	imgPath, _ = createTempImage()
	noTray = len(os.Args) > 1 && os.Args[1] == "--silent"
	cliControlify = (len(os.Args) > 1 && os.Args[1] == "--cli") || (len(os.Args) > 2 && os.Args[2] == "--cli")

	if noTray {
		mainFunc()
	} else if !noTray && !cliControlify {
		fmt.Println("Run executable with --silent to run without system tray and notifications.")
	} else {
		go mainFunc()
		systray.Run(onReady, onExit)
	}
}

func mainFunc() {
	controlifyName = "controlify_tray"

	if runtime.GOOS == "windows" {
		controlifyName = controlifyName + ".exe"
	}

	if cliControlify {
		controlifyArgs = "--cli"
	}

	// Create a context that is canceled when a signal is received
	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()

	signalChan := make(chan os.Signal, 1)
	signal.Notify(signalChan, os.Interrupt, syscall.SIGTERM)

	// Signal handling goroutine
	go func() {
		<-signalChan
		cancel()
	}()

	// Main loop
	for {
		select {
		case <-ctx.Done():
			onExit()
		default:
			spotifyRunning, err := utils.IsAppRunning("spotify")
			if err != nil {
				fmt.Printf("Error checking if Spotify is running: %v\n", err)
				time.Sleep(1 * time.Second)
				continue
			}

			controlifyRunning, err = utils.IsAppRunning("controlify")
			if err != nil {
				fmt.Printf("Error checking if Controlify is running: %v\n", err)
				time.Sleep(1 * time.Second)
				continue
			}

			if spotifyRunning {
				if !controlifyRunning {
					var msg string
					if cliControlify {
						msg = "Spotify is running, starting Controlify in CLI mode..."
					} else {
						msg = "Spotify is running, starting Controlify..."
					}

					if noTray {
						fmt.Println(msg)
					} else {
						_ = beeep.Alert("Controlify Watcher", msg, imgPath)
					}
					err := utils.StartApp(filepath.Join(exePath, controlifyName), controlifyArgs)
					if err != nil {
						msg = fmt.Sprintf("Error starting Controlify: %v", err)
						if noTray {
							fmt.Println(msg)
						} else {
							_ = beeep.Alert("Controlify Watcher", msg, imgPath)
						}
						onExit()
					}
				}
			} else {
				if controlifyRunning {
					msg := "Spotify is not running, closing Controlify..."
					if noTray {
						fmt.Println(msg)
					} else {
						_ = beeep.Alert("Controlify Watcher", msg, imgPath)
					}
					err := utils.CloseApp(controlifyName)
					if err != nil {
						msg := fmt.Sprintf("Error closing Controlify: %v\n", err)
						if noTray {
							fmt.Println(msg)
						} else {
							_ = beeep.Alert("Controlify Watcher", msg, imgPath)
						}
						onExit()
					}
				}
			}
			time.Sleep(1 * time.Second) // Add a sleep to avoid busy-waiting
		}
	}
}

func onReady() {
	systray.SetIcon(iconData)
	systray.SetTitle("Controlify Watcher")
	systray.SetTooltip("Controlify Watcher")

	systray.AddMenuItem("Controlify", "")
	systray.AddSeparator()
	mQuit := systray.AddMenuItemCheckbox("Quit", "Quit the whole app", false)
	go func() {
		for range mQuit.ClickedCh {
			systray.Quit()
		}
	}()
}

func onExit() {
	if controlifyRunning {
		err := utils.CloseApp(controlifyName)
		if err != nil {
			fmt.Printf("Error closing Controlify: %v\n", err)
		}
	}
	os.Exit(0)
}
