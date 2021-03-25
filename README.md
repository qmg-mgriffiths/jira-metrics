
# Analysis of Jira issues

## Overview
Generates `.csv` datasets and `.pdf` graphs relating to iterations, issues and the evolution of these in a single board on Jira.

## Requirements
- Docker
- A [Jira API key](https://id.atlassian.com/manage-profile/security/api-tokens)

## Usage
### For a single project
- (Optional) preload information for a project
  - See '[Preloading configuration](#preloading-configuration)' below
- Run `make`
  - You will be prompted for configuration if needed
- After this, datasets can be found within the `augmented/` subdirectory within a folder named after your project
- Graphs will be found in `graphs.pdf` under the same folder
- Tabular data will be found in `table-team.html` under the same folder
- When you want to regenerate all data, for example after a new iteration, run `make regen`
- You can generate a different team's data at any time using the above commands, notably `make config-<project>` or `make regen-<project>`
  - For these rules, any `<project>` specified in `configs.txt` may be used, case insensitively.

### For comparative data across projects
- First, ensure projects are configured as desired in `configs.txt`
  - See '[Preloading configuration](#preloading-configuration)' below
- Run `make summary` or `make table`
  - This will retrieve data for all boards in `config.txt`, and combine them into `all.iterations.csv`
  - The data in that `.csv` can be more easily viewed in your browser via `table.html`
  - Note: this only tracks the percentage _changes_ between metrics' values across iterations. `make summary-incl-raw` will include the raw values too - but be aware of the limitations of trying to compare raw data between teams!
- To regenerate any and all datasets (e.g. after a team completes an iteration), run `make reset-all`

### Preloading configuration
This tool is capable of remembering multiple projects' configuration: this is used for comparing data across teams, or to pre-load board details.

This configuration is stored in `configs.txt`. You can produce this yourself, or your company may have a template to use.

Each line of `configs.txt` should be in the format `<project>/<board>`, where:
  - `project` is the JIRA internal name: it should be visible in your URL bar as `projectKey=<project>` when viewing the relevant board
  - `board` is the human-friendly board name: it should be visible in the [breadcrumbs](https://en.wikipedia.org/wiki/Breadcrumb_navigation#Websites) when viewing the board's page

Running `make config-<project>` with any `<project>` in `configs.txt` will select it for future `make` or `make view` commands.

#### Other commands

- `make regen-<project>` will (re)produce data for the given team without updating configuration.
- `make zip` will produce `metrics.zip` containing some generated data.
- `make clean` will destroy all data for all projects
- `make cleanest` will clear out even your configuration.
