package main

import (
	"encoding/json"
	"fmt"
	"html/template"
	"os"
	"path"
	"path/filepath"
	"strings"

	yaml "gopkg.in/yaml.v2"
)

const (
	linksFile       = "links.yml"    // social media
	releaseFile     = "releases.yml" // release notes
	commonFile      = "common.json"  // endonyms & shared links
	templateSuffix  = ".tmpl"
	templateDir     = "templates"
	translationsDir = "translations"
)

var (
	outputDir  string
	commonPath = path.Join(translationsDir, commonFile)
	debug      = false
)

type site map[string]string         // an entry for each language
type sites map[string]site          // e.g. links.yml
type translations map[string]string // e.g. en.json
type releases []map[string][]string // e.g. releases.yml

// downloads page
type page struct {
	Sites        sites        // sites to link
	Translations translations // per language
	Common       translations // universal
	Releases     releases     // release notes
}

func init() {
	if _, ok := os.LookupEnv("DEBUG"); ok {
		fmt.Println("DEBUG mode enabled")
		debug = true
	}

	pwd, err := os.Getwd()
	if err != nil {
		fmt.Printf("unable to get working directory: %v", err)
		os.Exit(1)
	}
	parentDir := filepath.Dir(pwd)
	outputDir = path.Join(parentDir)
	if debug {
		fmt.Printf("Output directory set: %v\n", parentDir)
	}
}

func main() {
	err := updatePages("README.md")
	if err != nil {
		fmt.Printf("unable to update page: %v", err)
		os.Exit(1)
	}
	fmt.Println("🎉 Updates complete!")
	os.Exit(0)
}

// updatePages takes a target output EXAMPLE.md from template EXAMPLE.tmpl.md
// creating a file for each source translation available in the translations directory.
// English is the default. (e.g. EXAMPLE.md, EXAMPLE.en.md, EXAMPLE.ar.md, etc.)
func updatePages(target string) error {
	var sites sites
	err := readUnmarshalFile(linksFile, &sites)
	if err != nil {
		return fmt.Errorf("unable to load sites: %w", err)
	}
	if debug {
		fmt.Printf("sites:\n%v\n", sites)
	}

	var releases releases
	err = readUnmarshalFile(releaseFile, &releases)
	if err != nil {
		return fmt.Errorf("unable to load releases: %w", err)
	}
	if debug {
		fmt.Printf("releases:\n%v\n", releases)
	}

	var common translations
	err = readUnmarshalFile(commonPath, &common)
	if err != nil {
		return fmt.Errorf("unable to load common strings: %w", err)
	}
	if debug {
		fmt.Printf("common:\n%v\n", common)
	}

	files, err := os.ReadDir(translationsDir)
	if err != nil {
		return fmt.Errorf("unable to load translations: %w", err)
	}
	for _, file := range files {
		if file.Name() == commonFile {
			continue
		}
		name := file.Name()
		file := path.Join(translationsDir, name)
		lang := strings.Replace(name, filepath.Ext(name), "", -1)

		var translations translations
		err = readUnmarshalFile(file, &translations)
		if err != nil {
			return fmt.Errorf("unable to load translations: %w", err)
		}
		if debug {
			fmt.Printf("translations: %v\n", translations)
		}
		var page = page{
			Sites:        sites,
			Common:       common,
			Translations: translations,
			Releases:     releases,
		}

		templateName := fmt.Sprintf("%s%s", target, templateSuffix)
		template := filepath.Join(templateDir, templateName)
		outFilename := target
		if lang != "en" {
			splitTarget := strings.Split(target, ".")
			if len(splitTarget) != 2 {
				return fmt.Errorf("invalid target; could not be formatted: %s", target)
			}
			outFilename = fmt.Sprintf("%s.%s.%s", splitTarget[0], lang, splitTarget[1])
		}
		output := filepath.Join(outputDir, outFilename)
		err = createFromTemplate(&page, template, output)
		if err != nil {
			return fmt.Errorf("unable to update page: %w", err)
		}
	}
	return nil
}

// readUnmarshalFile reads a file, then attempts to unmarshal into the provided struct
func readUnmarshalFile(file string, destination any) error {
	data, err := os.ReadFile(file)
	if err != nil {
		return fmt.Errorf("error reading file '%s': %w", file, err)
	}
	if debug {
		fmt.Printf("read %v bytes from '%s'\n", len(data), file)
	}
	switch filepath.Ext(file) {
	case ".json":
		err = json.Unmarshal(data, destination)
		if err != nil {
			return fmt.Errorf("error unmarshalling JSON file '%s': %w", file, err)
		}
	case ".yaml", ".yml":
		err = yaml.Unmarshal(data, destination)
		if err != nil {
			return fmt.Errorf("error unmarshalling YAML file '%s': %w", file, err)
		}
	default:
		return fmt.Errorf("unsupported file type: %s", file)
	}
	return nil
}

// createFromTemplate parses a source file, applies a template, and writes the output to a file,
// all passed as paths.
func createFromTemplate(dataStruct any, templateFile string, outputFile string) error {
	tmpl, err := template.ParseFiles(templateFile)
	if err != nil {
		return fmt.Errorf("failed to parse template: %w", err)
	}
	f, err := os.Create(outputFile)
	if err != nil {
		return fmt.Errorf("failed to create file: %w", err)
	}
	defer f.Close()
	if debug {
		fmt.Printf("preparing to write structured data to '%s':\n%+v\n",
			outputFile,
			dataStruct,
		)
	}
	err = tmpl.Execute(f, dataStruct)
	if err != nil {
		return fmt.Errorf("failed to execute template: %w", err)
	}
	return nil
}
