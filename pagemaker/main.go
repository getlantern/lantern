package main

import (
	"encoding/json"
	"fmt"
	"html/template"
	"os"
	"path"
	"path/filepath"
	"strings"

	"github.com/tdewolff/minify/v2"
	"github.com/tdewolff/minify/v2/html"
	yaml "gopkg.in/yaml.v2"
)

const (
	linksFile       = "links.yml"    // social media
	releaseFile     = "releases.yml" // release notes
	commonFile      = "common.json"  // endonyms & shared links
	templateSuffix  = ".tmpl"
	templateDir     = "templates"
	translationsDir = "translations"
	outputDir       = "outputs"
)

var (
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
}

func main() {
	pwd, err := os.Getwd()
	if err != nil {
		fmt.Printf("unable to get working directory: %v\n", err)
		os.Exit(1)
	}
	parentDir := filepath.Dir(pwd)

	// download page: https://github.com/getlantern/lantern
	err = updateDownloadsPages(parentDir)
	if err != nil {
		fmt.Printf("unable to update page: %v\n", err)
		os.Exit(1)
	}

	// email footer: downloads@getlantern.org (et al.)
	err = updateFooter(outputDir)
	if err != nil {
		fmt.Printf("unable to update footer: %v\n", err)
		os.Exit(2)
	}

	fmt.Println("🎉 Updates complete!")
}

// updateFooter writes a single, minimal, language-agnostic text for
// downloads@getlantern.org [TODO or help desk email footers]
func updateFooter(destinationDir string) error {
	// English is the default (e.g. EXAMPLE.md, EXAMPLE.zh.md, EXAMPLE.ar.md, etc.)
	// File will be written to destinationDir.
	baseName := "footer.html"
	templateName := fmt.Sprintf("%s%s", baseName, templateSuffix)
	template := filepath.Join(templateDir, templateName)
	outFilename := filepath.Join(destinationDir, baseName)
	if debug {
		fmt.Printf("Creating '%s'\n", outFilename)
	}
	defaultLang := "en.json"
	filePath := path.Join(translationsDir, defaultLang)
	page, err := loadInfo(filePath)
	if err != nil {
		return fmt.Errorf("unable to load info for '%s': %w", filePath, err)
	}
	err = createFromTemplate(page, template, outFilename)
	if err != nil {
		return fmt.Errorf("unable to update footer: %w", err)
	}
	// also minify the output
	err = makeMinifiedCopy(outFilename)
	if err != nil {
		return fmt.Errorf("unable to minify footer: %w", err)
	}
	return nil
}

// minify takes a file path and minifies the html contents into a new file
// ending in .min.html
func makeMinifiedCopy(filepath string) error {
	m := minify.New()
	m.AddFunc("text/html", html.Minify)
	data, err := os.ReadFile(filepath)
	if err != nil {
		return fmt.Errorf("unable to read file '%s': %w", filepath, err)
	}
	minified, err := m.String("text/html", string(data))
	if err != nil {
		return fmt.Errorf("unable to minify data: %w", err)
	}
	extension := path.Ext(filepath)
	bareName := strings.Replace(filepath, extension, "", -1)
	minifiedPath := fmt.Sprintf("%s.min%s", bareName, extension)

	err = os.WriteFile(minifiedPath, []byte(minified), 0644)
	if err != nil {
		return fmt.Errorf("unable to write minified data: %w", err)
	}
	return nil
}

// updateDownloadsPages takes a desired target output EXAMPLE.md and uses template EXAMPLE.tmpl.md
// to create a new file for each source translation in the translations directory.
//
// English is the default (e.g. EXAMPLE.md, EXAMPLE.zh.md, EXAMPLE.ar.md, etc.).
// File will be written to destinationDir.
func updateDownloadsPages(destinationDir string) error {
	baseName := "README.md"
	// we want to update the downloads page for every available translation
	files, err := os.ReadDir(translationsDir)
	if err != nil {
		return fmt.Errorf("unable to load translations: %w", err)
	}
	for _, file := range files {
		name := file.Name()
		if name == commonFile {
			continue
		}
		filePath := path.Join(translationsDir, name)
		lang := strings.Replace(name, filepath.Ext(name), "", -1)

		page, err := loadInfo(filePath)
		if err != nil {
			return fmt.Errorf("unable to load info for '%v': %w", lang, err)
		}

		templateName := fmt.Sprintf("%s%s", baseName, templateSuffix)
		template := filepath.Join(templateDir, templateName)
		outFilename := filepath.Join(destinationDir, baseName)
		// format filename for non-English languages (e.g. EXAMPLE.zh.md)
		if lang != "en" {
			splitTarget := strings.Split(baseName, ".")
			if len(splitTarget) != 2 {
				return fmt.Errorf("invalid target; could not be formatted: %s", baseName)
			}
			outFilename = filepath.Join(
				destinationDir,
				fmt.Sprintf("%s.%s.%s", splitTarget[0], lang, splitTarget[1]),
			)
			// fmt.Sprintf("%s.%s.%s", splitTarget[0], lang, splitTarget[1])
		}
		if debug {
			fmt.Printf("Creating '%s'\n", outFilename)
		}
		err = createFromTemplate(&page, template, outFilename)
		if err != nil {
			return fmt.Errorf("unable to update page: %w", err)
		}
	}
	return nil
}

// loadInfo intakes a language then parses files and returns a struct
// using common resources, files, and the language's translations
func loadInfo(translationFile string) (page, error) {
	var sites sites
	err := readUnmarshalFile(linksFile, &sites)
	if err != nil {
		return page{}, fmt.Errorf("unable to load sites: %w", err)
	}
	if debug {
		fmt.Printf("sites:\n%v\n\n", sites)
	}

	var releases releases
	err = readUnmarshalFile(releaseFile, &releases)
	if err != nil {
		return page{}, fmt.Errorf("unable to load releases: %w", err)
	}
	if debug {
		fmt.Printf("releases:\n%v\n", releases)
	}

	// not language specific
	var common translations
	err = readUnmarshalFile(commonPath, &common)
	if err != nil {
		return page{}, fmt.Errorf("unable to load common strings: %w", err)
	}
	if debug {
		fmt.Printf("common:\n%v\n", common)
	}

	// language specific

	var translations translations
	err = readUnmarshalFile(translationFile, &translations)
	if err != nil {
		return page{}, fmt.Errorf("unable to load translations: %w", err)
	}
	if debug {
		fmt.Printf("translations:\n%v\n", translations)
	}

	page := page{
		Sites:        sites,
		Common:       common,
		Translations: translations,
		Releases:     releases,
	}
	if debug {
		fmt.Printf("page: %+v\n", page)
	}
	return page, nil
}

// readUnmarshalFile reads a file, then attempts to unmarshal into the provided struct
func readUnmarshalFile(filePath string, destination any) error {
	data, err := os.ReadFile(filePath)
	if err != nil {
		return fmt.Errorf("error reading file '%s': %w", filePath, err)
	}
	if debug {
		fmt.Printf("read %v bytes from '%s'\n", len(data), filePath)
	}
	switch filepath.Ext(filePath) {
	case ".json":
		err = json.Unmarshal(data, destination)
		if err != nil {
			return fmt.Errorf("error unmarshalling JSON file '%s': %w", filePath, err)
		}
	case ".yaml", ".yml":
		err = yaml.Unmarshal(data, destination)
		if err != nil {
			return fmt.Errorf("error unmarshalling YAML file '%s': %w", filePath, err)
		}
	default:
		return fmt.Errorf("unsupported file type: %s", filePath)
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
