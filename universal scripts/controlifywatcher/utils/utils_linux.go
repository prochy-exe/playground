//go:build linux

package utils

import (
	"os/exec"
	"strings"
)

func IsAppRunning(appName string) (bool, error) {
	cmd := exec.Command("pgrep", "-fl", appName)
	cmd.Stdout = nil
	cmd.Stderr = nil

	output, err := cmd.Output()
	if err != nil {
		return false, err
	}

	appNameLower := strings.ToLower(appName)
	outputLower := strings.ToLower(string(output))

	outputLower = strings.ReplaceAll(outputLower, "controlifywatcher", "poisedwatcher") // Hack to avoid detecting itself

	return strings.Contains(outputLower, appNameLower), nil
}

func StartApp(appPath string, argument string) error {
	cmd := exec.Command("xdg-open", appPath+" "+argument)
	cmd.Stdout = nil
	cmd.Stderr = nil
	return cmd.Start()
}

func CloseApp(appName string) error {
	cmd := exec.Command("pkill", appName)
	cmd.Stdout = nil
	cmd.Stderr = nil
	return cmd.Run()
}
