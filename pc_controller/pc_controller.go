package main

import (
	"bufio"
	"encoding/json"
	"fmt"
	"net/http"
	"os"
	"os/exec"
	"path/filepath"
	"reflect"
	"runtime"
	"strconv"
	"strings"
)

type Config struct {
	UseSSL       *bool  `json:"use_ssl"`
	CertFile     string `json:"certfile" optional:"true"`
	KeyFile      string `json:"keyfile" optional:"true"`
	PCIp         string `json:"pc_ip"`
	PCUsername   string `json:"pc_username"`
	PCMac        string `json:"pc_mac"`
	OffCommand   string `json:"off_command"`
	SleepCommand string `json:"sleep_command"`
	OnCommand    string `json:"on_command"`
}

func getConfigDir() (string, error) {
	var configDir string

	if runtime.GOOS == "windows" {
		appData := os.Getenv("APPDATA")
		if appData == "" {
			return "", fmt.Errorf("APPDATA environment variable is not set")
		}
		configDir = filepath.Join(appData, "pc_controller")
	} else {
		homeDir, err := os.UserHomeDir()
		if err != nil {
			return "", err
		}
		configDir = filepath.Join(homeDir, ".config", "pc_controller")
	}

	return configDir, nil
}

func main() {
	config, err := loadConfig()
	if err != nil {
		fmt.Println("Error loading config:", err)
		return
	}

	http.HandleFunc("/on", func(w http.ResponseWriter, r *http.Request) {
		if runtime.GOOS == "windows" {
			exec.Command("cmd", "/C", fmt.Sprintf("%s %s", config.OnCommand, config.PCMac))
		} else {
			exec.Command("sh", "-c", fmt.Sprintf("%s %s", config.OnCommand, config.PCMac))
		}
		fmt.Fprintf(w, "Turning the PC on")
	})

	http.HandleFunc("/off", func(w http.ResponseWriter, r *http.Request) {
		if runtime.GOOS == "windows" {
			exec.Command("cmd", "/C", fmt.Sprintf("ssh %s@%s %s", config.PCUsername, config.PCIp, config.OffCommand))
		} else {
			exec.Command("sh", "-c", fmt.Sprintf("ssh %s@%s %s", config.PCUsername, config.PCIp, config.OffCommand))
		}
		fmt.Fprintf(w, "Turning the PC off")
	})

	http.HandleFunc("/sleep", func(w http.ResponseWriter, r *http.Request) {
		if runtime.GOOS == "windows" {
			exec.Command("cmd", "/C", fmt.Sprintf("ssh %s@%s %s", config.PCUsername, config.PCIp, config.SleepCommand))
		} else {
			exec.Command("sh", "-c", fmt.Sprintf("ssh %s@%s %s", config.PCUsername, config.PCIp, config.SleepCommand))
		}
		fmt.Fprintf(w, "Putting the PC to sleep")
	})

	address := ":8081"
	fmt.Printf("Server is running on http://localhost%s\n", address)
	if config.UseSSL != nil && *config.UseSSL {
		fmt.Printf("Server is running on https://localhost%s\n", address)
		err := http.ListenAndServeTLS(address, config.CertFile, config.KeyFile, nil)
		if err != nil {
			fmt.Println("Error starting HTTPS server:", err)
		}
	} else {
		err := http.ListenAndServe(address, nil)
		if err != nil {
			fmt.Println("Error starting HTTP server:", err)
		}
	}
}

func loadConfig() (Config, error) {
	var config Config
	var configPath string
	var userConfigDir string
	userConfigDir, err := getConfigDir()
	// Get the path to the executable
	exePath, err := os.Executable()

	// Get the directory of the executable
	exeDir := filepath.Dir(exePath)

	configPaths := []string{
		filepath.Join(userConfigDir, "config.json"),
		filepath.Join("utils", "config.json"),
		filepath.Join(exeDir, "config.json"),
	}

	for _, path := range configPaths {
		if _, err := os.Stat(path); err == nil {
			configPath = path
			break
		}
	}

	if configPath == "" {
		config, err := createConfig()
		if err != nil {
			return config, err
		}
		return config, nil
	}

	data, err := os.ReadFile(configPath)
	if err != nil {
		return config, err
	}

	if err := json.Unmarshal(data, &config); err != nil {
		return config, err
	}

	if missingKeys := findMissingKeys(config); len(missingKeys) > 0 {
		if err := promptMissingKeys(&config, missingKeys); err != nil {
			return config, err
		}

		if err := saveConfigToFile(config, configPath); err != nil {
			return config, err
		}
	}

	return config, nil
}

func createConfig() (Config, error) {
	var config Config
	configDir, err := getConfigDir()
	if err != nil {
		return config, err
	}

	reader := bufio.NewReader(os.Stdin)

	configType := reflect.TypeOf(config)

	fmt.Println("Please provide configuration values:")

	for i := 0; i < configType.NumField(); i++ {
		field := configType.Field(i)
		jsonTag := field.Tag.Get("json")

		fmt.Printf("Enter %s", jsonTag)

		// Prompt the user for input based on field type
		if field.Type.Kind() == reflect.Ptr && field.Type.Elem().Kind() == reflect.Bool {
			fmt.Print(" (true/false): ")
			input, _ := reader.ReadString('\n')
			input = strings.TrimSpace(input)

			boolValue, err := strconv.ParseBool(input)
			if err != nil {
				return config, err
			}

			// Create a new boolean pointer value and set it
			value := reflect.New(field.Type.Elem())
			value.Elem().SetBool(boolValue)
			reflect.ValueOf(&config).Elem().FieldByName(field.Name).Set(value)
		} else {
			fmt.Print(": ")
			input, _ := reader.ReadString('\n')
			value := strings.TrimSpace(input)

			reflect.ValueOf(&config).Elem().FieldByName(field.Name).SetString(value)
		}
	}

	err = saveConfigToFile(config, filepath.Join(configDir, "config.json"))
	if err != nil {
		return config, err
	}

	return config, nil
}

func findMissingKeys(config Config) []string {
	var missingKeys []string

	configValue := reflect.ValueOf(config)
	configType := reflect.TypeOf(config)

	for i := 0; i < configType.NumField(); i++ {
		field := configType.Field(i)
		jsonTag := field.Tag.Get("json")
		optionalTag := field.Tag.Get("optional")

		// Skip if the field is optional
		if optionalTag == "true" {
			continue
		}

		if jsonTag != "" {
			value := configValue.FieldByName(field.Name)
			if value.Kind() == reflect.Ptr && value.IsNil() {
				missingKeys = append(missingKeys, field.Name)
			} else if !value.IsValid() || (value.Kind() != reflect.Bool && reflect.DeepEqual(value.Interface(), reflect.Zero(value.Type()).Interface())) {
				missingKeys = append(missingKeys, field.Name)
			}
		}
	}

	return missingKeys
}

func promptMissingKeys(config *Config, keys []string) error {
	reader := bufio.NewReader(os.Stdin)

	fmt.Println("Some configuration keys are missing:")

	for _, key := range keys {
		field, _ := reflect.TypeOf(*config).FieldByName(key)
		fmt.Printf("Enter value for %s", key)

		// Prompt the user for input based on field type
		if field.Type.Kind() == reflect.Ptr && field.Type.Elem().Kind() == reflect.Bool {
			fmt.Print(" (true/false): ")
			input, _ := reader.ReadString('\n')
			input = strings.TrimSpace(input)

			boolValue, err := strconv.ParseBool(input)
			if err != nil {
				return err
			}

			// Create a new boolean pointer value and set it
			value := reflect.New(field.Type.Elem())
			value.Elem().SetBool(boolValue)
			reflect.ValueOf(config).Elem().FieldByName(key).Set(value)
		} else {
			fmt.Print(": ")
			input, _ := reader.ReadString('\n')
			value := strings.TrimSpace(input)

			reflect.ValueOf(config).Elem().FieldByName(key).SetString(value)
		}
	}

	return nil
}

func saveConfigToFile(config Config, filename string) error {
	var existingConfig map[string]interface{}

	data, err := os.ReadFile(filename)
	if err == nil {
		err = json.Unmarshal(data, &existingConfig)
		if err != nil {
			return err
		}
	} else {
		existingConfig = make(map[string]interface{})
	}

	// Convert the new config to a map
	newConfigMap := structToMap(config)

	// Update the existing config with the new values
	for key, value := range newConfigMap {
		if value != nil {
			existingConfig[key] = value
		}
	}

	data, err = json.MarshalIndent(existingConfig, "", "  ")
	if err != nil {
		return err
	}

	dir := filepath.Dir(filename)
	err = os.MkdirAll(dir, 0755)
	if err != nil {
		return err
	}

	err = os.WriteFile(filename, data, 0644)
	if err != nil {
		return err
	}

	fmt.Printf("Configuration saved to %s\n", filename)
	return nil
}

func structToMap(config Config) map[string]interface{} {
	configMap := make(map[string]interface{})
	configValue := reflect.ValueOf(config)
	configType := reflect.TypeOf(config)

	for i := 0; i < configType.NumField(); i++ {
		field := configType.Field(i)
		value := configValue.FieldByName(field.Name).Interface()
		jsonTag := field.Tag.Get("json")
		if jsonTag != "" {
			configMap[jsonTag] = value
		} else {
			configMap[field.Name] = value
		}
	}

	return configMap
}
