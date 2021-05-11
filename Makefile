SHELL=/bin/bash

R=docker run -i --rm -v $$PWD:/host -w /host r-base:4.0.0
DOCKER_TAG_R=r-jira-stats:0.1.0
DOCKER_TAG_PYTHON=python-jira-stats:0.1.0
R_CUSTOM=docker run -i --rm -v $$PWD:/host $(DOCKER_TAG_R)
PYTHON=docker run -ti --rm --net host -v $$PWD:/host $(DOCKER_TAG_PYTHON)

# These two variables should be set through recursive make calls only
PROJECT=
BOARD=

# Derived or universal configuration values
BASE_CONFIG=.apikey .email .jira-url
DIR=$(shell echo "$(PROJECT) $(BOARD)" | tr '[A-Z]' '[a-z]' | tr '/' ' ' | tr -d '-' | sed -E "s/ +/_/g")
ARGS=$(shell [ -n "$(PROJECT)" ] && [ -n "$(BOARD)" ] && echo "'$(PROJECT)' '$(BOARD)' '$(DIR)'")

# Turning configs.json into meaningful parameters based on a passed-in wildcard
CONFIG_INDEX_FROM_PROJECT=map(.project | test("^$*$$"; "i")?) | index(true)
CONFIG_INDEX=[[ "$*" =~ ^[0-9]+$$ ]] && echo "$$(( $* - 1 ))" || echo '$(CONFIG_INDEX_FROM_PROJECT)'

CONFIG_FROM_WILDCARD=jq -e 'nth($(shell $(CONFIG_INDEX)))?' configs.json
MAKE_FROM_WILDCARD=$(MAKE) $(shell jq -r 'nth($(shell $(CONFIG_INDEX))) | ("PROJECT=\""+.project + "\" BOARD=\""+.board+"\"")' configs.json)
ALL_PRESETS=preset-1 $(shell jq -r 'to_entries | del(.[0]) | map("preset-"+(.key+1 | tostring)) | join(" ")' configs.json 2>/dev/null)

# Default rule: generate and view data for the first team in configs.json
view: view-1

view-team-visualisations: $(DIR)/graphs.pdf $(DIR)/table-team.html
	open $^

generate-team-visualisations: $(DIR)/graphs.pdf $(DIR)/table-team.html

regen reset: clean view

view-%: config-exists-for-%
	$(MAKE_FROM_WILDCARD) view-team-visualisations

preset-%: config-exists-for-%
	@echo
	$(MAKE_FROM_WILDCARD) generate-team-visualisations

all all-teams compare-teams presets: $(ALL_PRESETS)
	$(MAKE) comparison-table

table-team: $(DIR)/table-team.html
	open $<
comparison-table summary table: table.html
	open $<
summary-incl-raw: all.iterations.incl.raw.csv
	@echo "See $@ for raw and change data. Be wary of comparing raw data between teams!"
	@echo "Note: tabular presentation is not yet available for raw data." >&2
comparison-table-incl-raw table-incl-raw: table-incl-raw.html
	open $<

zip: metrics.zip
metrics.zip: table.html lib */table-team.html */lib */graphs.pdf all.iterations.csv
	@rm -f $@
	zip -rq $@ $^

$(DIR)/table-team.html: table.r table.*.r common.r $(DIR)/augmented/metrics.csv
	@$(MAKE) docker-built-r
	@rm -f $@
	$(R_CUSTOM) ./$< $(ARGS)

table.html lib: table.r table.*.r common.r all.iterations.csv
	@$(MAKE) docker-built-r
	@rm -f $@
	$(R_CUSTOM) ./$<

table-incl-raw.html: table.r table.*.r common.r all.iterations.incl.raw.csv
	@$(MAKE) docker-built-r
	@rm -f $@
	@# TODO not ready for use yet
	$(R_CUSTOM) ./$< --include-raw-data

docker-built-r:
	@[ -n "$$(docker images $(DOCKER_TAG_R) -q)" ] || $(MAKE) build-docker-r
docker-built-python:
	@[ -n "$$(docker images $(DOCKER_TAG_PYTHON) -q)" ] || $(MAKE) build-docker-python

build-docker-r:
	@echo "Building docker image for R. This can take up to ten minutes." >&2
	docker build -f Dockerfile-r -t $(DOCKER_TAG_R) .
build-docker-python:
	@echo "Building docker image for Python." >&2
	docker build -f Dockerfile-python -t $(DOCKER_TAG_PYTHON) .

regen-all regen-presets reset-all reset-presets: clean compare-teams
	@echo "Data for all teams is now available."
all.iterations.csv: combine.r $(shell ls *_*/augmented/iterations.full.csv 2>/dev/null || echo "$(DIR)/augmented/iterations.full.csv")
	$(R) ./$<
	@echo "Combined data for all projects can now be found in: $@"
all.iterations.incl.raw.csv: combine.r $(shell ls *_*/augmented/iterations.full.csv 2>/dev/null || echo "$(DIR)/augmented/iterations.full.csv")
	$(R) ./$< --include-raw-data

$(DIR)/augmented/metrics.csv: combine.r $(DIR)/augmented/iterations.full.csv
	$(R) ./$< $(ARGS) --include-raw-data

$(DIR)/augmented/iterations.full.csv: tidy.r tidy.functions.r $(DIR)/issues.csv
	@[ -d $(@D) ] || mkdir -p $(@D)
	$(R) ./$< $(ARGS)

graphs.pdf: $(DIR)/graphs.pdf
$(DIR)/graphs.pdf: graph.r $(DIR)/augmented/iterations.full.csv
	@$(MAKE) docker-built-r
	$(R_CUSTOM) ./$< $(ARGS)

$(DIR)/issues.csv: retrieve.py $(BASE_CONFIG)
	@([[ -n "$(PROJECT)" ]] && [[ -n "$(BOARD)" ]]) || ( \
		echo 'No configuration found: please run `make`, `make-<project>` or `make compare-teams`.' >&2 && exit 1)
	@[ -d $(DIR) ] || mkdir $(DIR)
	@echo "$(PROJECT)" >$(DIR)/.project
	@echo "$(BOARD)" >$(DIR)/.board
	@$(MAKE) docker-built-python
	$(PYTHON) ./$< $(ARGS)

get-boards get-all-boards: $(BASE_CONFIG)
	./retrieve.py --get-all-boards

config-exists-for-%:
	@[ -f configs.json ] || (echo "Error: no configs.json file found." >&2 && exit 1)
	@jq -e 'type=="array" and (map(type=="object" and has("project") and has("board")) | index(false) == null)' configs.json >/dev/null || \
		(echo "Error: configs.json must contain an array of objects, each specifying 'board' and 'project'" >&2 && exit 1)
	@$(CONFIG_FROM_WILDCARD) >/dev/null || ( \
		([[ "$*" =~ ^[0-9]+$$ ]] \
			&& echo "Error: fewer than $* projects defined in config.json" >&2 \
			|| echo "Error: project '$*' not found in configs.json" >&2) \
		&& exit 1)
regen-%: config-exists-for-%
	@echo "Recalculating board \"$$(\
		$(CONFIG_FROM_WILDCARD) | cut -d/ -f2)\" of project \"$$(\
		$(CONFIG_FROM_WILDCARD) | cut -d/ -f1)\"."
	@$(MAKE_FROM_WILDCARD) -W .jira-url view-team-visualisations

.email:
	@echo "Please enter the email address you use to log into Jira"
	@read email && echo "$$email" >$@

.apikey:
	@echo "Please enter your API key from JIRA, as per" >&1
	@echo "https://id.atlassian.com/manage-profile/security/api-tokens"
	@read apikey && echo "$$apikey" >$@

.jira-url:
	@echo "Please enter the URL of Jira, e.g. https://<company>.atlassian.net/"
	@read url && echo "$$url" >$@

# Don't remove intermediate files after generation
.SECONDARY:

# Always regenerate the .zip file if requested
.PHONY: metrics.zip

print-%:
	@echo "$*: $($*)"

cleanish:
	rm -rf augmented/ *.pdf

clean-%:
	$(PRESET_MAKE) clean-dir
clean-dir:
	rm -rf $(DIR)

clean:
	rm -rf *_*/ augmented/ lib **/lib **/*.pdf **/*.csv **/*.json **/*.html **/*.zip

cleaner:
	git clean -xdn -e .email -e .apikey

cleanest:
	git clean -xdf
