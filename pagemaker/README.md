# pagemaker
Tool for automatically updating downloads page through source files.

## source files
Update source files with newest information.
- [`links.yml`](./links.yml)
- [`releases.yml`](./releases.yml)

## templates
Templates in the [templates](./templates) directory can be altered, and will affect all languages.
- [`README.md.tmpl`](./templates/README.md.tmpl)

## translations
For every translation file in the [translations](./translations) directory, a new file will be made.
- [`common.json`](./translations/common.json) has permanent links and endonyms common to all translations

## automatic actions
Any file changed in this directory will trigger an update of all translations using the _source files_, _templates_, and _translations_ cited above.
- [update.yml](../.github/workflows/update.yml)
