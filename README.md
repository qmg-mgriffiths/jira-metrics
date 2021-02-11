
# Analysis of Jira issues

## Overview
Generates `.csv` datasets and `.pdf` graphs relating to iterations, issues and the evolution of these in a single board on Jira.

## Usage
- (Optional) pick a project as per 'To configure' below.
- Run `make`
- After this, datasets can be found within the `augmented/` directory.
- Graphs will be found in `graphs.pdf`.

#### To configure
For the car or platform team, you can just type `make config-platform` or `make config-car` to pre-load some details. Either way, any of the `make` commands in the previous section will prompt you for required information as needed.

#### To regenerate data
When a new iteration is complete, run `make regen` to regenerate all data from scratch.

Alternatively, `make clean` will destroy all data, or `make cleanest` will clear out even your configuration.

## Requirements
- Docker
- Python 3
- A [Jira API key](https://id.atlassian.com/manage-profile/security/api-tokens)
