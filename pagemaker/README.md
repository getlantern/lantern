# pagemaker
Tool for automatically updating downloads page through source files.

## process
1. Source data at `links.yml` or `releases.yml` can be updated
1. GitHub action `update.yml` will be automatically triggered to update pages
1. `update.yml` runs go program `./pagemaker` which
    - reads source data at `links.yml` and `releases.yml`
    - reads `translations` directory for every localized language
    - parses `templates` directory for `common.json` and each `<language>.json`
    - writes new README files with updated names, links and localizations
1. Changes are automatically committed
