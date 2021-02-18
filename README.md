
# Analysis of Jira issues

## Overview
Generates `.csv` datasets and `.pdf` graphs relating to iterations, issues and the evolution of these in a single board on Jira.

## Usage
### For a single project
- (Optional) preload information for a project with one of these commands:
  - `make config-platform`
  - `make config-car`
  - `make config-home-product`
  - `make config-home-tech-debt-bau`
  - `make config-home-gdpr`
  - `make config-payments`
- Run `make`
- After this, datasets can be found within the `augmented/` directory
- Graphs will be found in `graphs.pdf` under a directory named after your project
- When you want to regenerate all data, for example after a new iteration, run `make regen`

### For comparative data across projects
- First, ensure projects are configured as desired
  - Check/modify `configs.txt` to list all projects you are interested in. These should be entered one per line, in the format `<project>/<board>`, where
    - `project` is the JIRA internal name: it should be visible in your URL bar as `projectKey=<project>` when viewing the relevant board
    - `board` is the human-friendly board name: it should be visible in the [breadcrumbs](https://en.wikipedia.org/wiki/Breadcrumb_navigation#Websites) when viewing the board's page
- Run `make summary`
  - This will retrieve data for all boards in `config.txt`, and combine them into `all.iterations.csv`
  - This only tracks the percentage _changes_ between metrics' values across iterations. `make summary-incl-raw` will include the raw values too - but be aware of limitations of trying to compare raw data between teams!
- To regenerate any and all datasets (e.g. after a team completes an iteration), run `make reset-all`

#### Other commands

- `make clean` will destroy all data for all projects
- `make cleanest` will clear out even your configuration.

## Requirements
- Docker
- Python 3
- A [Jira API key](https://id.atlassian.com/manage-profile/security/api-tokens)
