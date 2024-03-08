# pagemaker
Tool for automatically updating downloads page through source files.

## process
1. Updates are made to social media (`links.yml`) or release notes (`releases.yml`)
1. GitHub action `update.yml` is triggered
1. Go program `./pagemaker` executes
    - reads files `links.yml` and `releases.yml`
    - reads `/translations` for every localized language
    - parses `/templates` for `common.json` and each `<language>.json`
    - writes new README files with updated names, links and localizations
1. Changes are automatically committed
