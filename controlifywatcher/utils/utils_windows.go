//go:build windows

package utils

import (
	"strings"
	"unsafe"

	"golang.org/x/sys/windows"
)

func IsAppRunning(appName string) (bool, error) {
	handle, err := windows.CreateToolhelp32Snapshot(windows.TH32CS_SNAPPROCESS, 0)
	if err != nil {
		return false, err
	}
	defer windows.CloseHandle(handle)

	var entry windows.ProcessEntry32
	entry.Size = uint32(unsafe.Sizeof(entry))

	err = windows.Process32First(handle, &entry)
	if err != nil {
		return false, err
	}

	appNameLower := strings.ToLower(appName)
	for {
		processName := windows.UTF16ToString(entry.ExeFile[:])
		if strings.Contains(strings.ToLower(processName), appNameLower) && !strings.Contains(strings.ToLower(processName), "controlifywatcher.exe") {
			return true, nil
		}
		err = windows.Process32Next(handle, &entry)
		if err != nil {
			break
		}
	}
	return false, nil
}

func StartApp(appPath string, argument string) error {
	commandLine := appPath + " " + argument
	commandLineUTF16, err := windows.UTF16PtrFromString(commandLine)
	if err != nil {
		return err
	}

	var si windows.StartupInfo
	si.Cb = uint32(unsafe.Sizeof(si))
	var pi windows.ProcessInformation

	err = windows.CreateProcess(
		nil,
		commandLineUTF16,
		nil,
		nil,
		false,
		0,
		nil,
		nil,
		&si,
		&pi,
	)
	if err != nil {
		return err
	}
	windows.CloseHandle(pi.Thread)
	windows.CloseHandle(pi.Process)
	return nil
}

func CloseApp(appName string) error {
	handle, err := windows.CreateToolhelp32Snapshot(windows.TH32CS_SNAPPROCESS, 0)
	if err != nil {
		return err
	}
	defer windows.CloseHandle(handle)

	var entry windows.ProcessEntry32
	entry.Size = uint32(unsafe.Sizeof(entry))

	err = windows.Process32First(handle, &entry)
	if err != nil {
		return err
	}

	appNameLower := strings.ToLower(appName)
	for {
		processName := windows.UTF16ToString(entry.ExeFile[:])
		if strings.Contains(strings.ToLower(processName), appNameLower) {
			processHandle, err := windows.OpenProcess(windows.PROCESS_TERMINATE, false, entry.ProcessID)
			if err != nil {
				return err
			}
			defer windows.CloseHandle(processHandle)

			err = windows.TerminateProcess(processHandle, 0)
			if err != nil {
				return err
			}
		}
		err = windows.Process32Next(handle, &entry)
		if err != nil {
			break
		}
	}
	return nil
}
