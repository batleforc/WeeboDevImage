package main

import (
	"log"
	"os"
	"path/filepath"
	"strings"
	"text/template"

	"gopkg.in/yaml.v3"
)

type ConfigVal struct {
	BaseImage string `yaml:"baseImage"`
	Repo      string `yaml:"repo"`
	RegSource string `yaml:"regSource"`
}

func (c *ConfigVal) GetConfigFromFile() *ConfigVal {
	yamlFile, err := os.ReadFile("config.yaml")
	if err != nil {
		log.Panicf("Error reading config file: %v \n", err)
	}
	err = yaml.Unmarshal(yamlFile, c)
	if err != nil {
		log.Panicf("Error parsing config file: %v \n", err)
	}
	return c
}

func main() {
	var config ConfigVal
	config.GetConfigFromFile()

	if config.BaseImage == "" {
		log.Panic("BaseImage is not set in the config file")
	}

	os.Chdir("..")

	// find all the Containerfile in the subdirectories
	Containerfile := []string{}
	err := filepath.Walk(".", func(path string, info os.FileInfo, err error) error {
		if info.IsDir() && (info.Name() == ".git" || info.Name() == ".github" || info.Name() == ".vscode" || info.Name() == "template" || info.Name() == "src-template") {
			return filepath.SkipDir
		}
		if strings.Contains(strings.ToLower(path), "dockerfile") || strings.Contains(strings.ToLower(path), "containerfile") {
			Containerfile = append(Containerfile, path)
		}
		return nil
	})
	if err != nil {
		log.Printf("Error walking through the directories: %v \n", err)
	}
	log.Println("Containerfile found: ", Containerfile)
	log.Println("Starting preparing the Containerfile")
	for _, file := range Containerfile {
		log.Println("Processing: ", file)
		// read the file
		tmpl, err := template.New("Containerfile").ParseGlob(file)
		if err != nil {
			log.Panicf("Error parsing the file: %v \n", err)
		}
		output, err := os.Create(file)
		if err != nil {
			log.Panicf("Error creating the file: %v \n", err)
		}
		defer output.Close()
		err = tmpl.Execute(output, config)
		if err != nil {
			log.Panicf("Error executing the file: %v \n", err)
		}
	}
	log.Println("Containerfile preparation completed")
}
