R=docker run -i --rm -v $$PWD:/host -w /host r-base:4.0.0
DOCKER_TAG_R=r-jira-stats:0.0.1
R_CUSTOM=docker run -i --rm -v $$PWD:/host -w /host $(DOCKER_TAG_R)

# Configuration for users wanting just one board's stats
PROJECT_CONFIG=.project .board
PROJECT=$(shell cat .project 2>/dev/null)
BOARD=$(shell cat .board 2>/dev/null)

# Configuration supporting single-board users and multi-board combined stats
BASE_CONFIG=.apikey .email .jira-url
DIR=$(shell echo "$(PROJECT) $(BOARD)" | tr '[A-Z]' '[a-z]' | tr '/' ' ' | tr -d '-' | sed -E "s/ +/_/g")
ARGS=$(shell [ -n "$(PROJECT)" ] && [ -n "$(BOARD)" ] && echo "'$(PROJECT)' '$(BOARD)' '$(DIR)'")

# Turning configs.txt into meaningful parameters based on a passed-in wildcard
CONFIGS=cat configs.txt 2>/dev/null | sed -E 's/ *\#.*//' | grep .
MAKE_ARGS_FROM_CONFIG=sed -E "s|^([^/]+)/(.+)|PROJECT='\\1' BOARD='\\2'|g"
CONFIG_FROM_PROJECT=$(CONFIGS) | awk "NR==$$($(CONFIGS) | grep -ni "^$*/" | cut -d: -f1)" 2>/dev/null
CONFIG_FROM_NUMBER=$(CONFIGS) | awk 'NR==$*' 2>/dev/null

CONFIG_FROM_WILDCARD=(config=$$($(CONFIG_FROM_NUMBER)) && ([ -n "$$config" ] && echo "$$config") || $(CONFIG_FROM_PROJECT))
MAKE_FROM_WILDCARD=$(MAKE) $(shell $(CONFIG_FROM_WILDCARD) | $(MAKE_ARGS_FROM_CONFIG))

view view-team-visualisations: $(DIR)/graphs.pdf $(DIR)/table-team.html
	open $^

team-visualisations: $(DIR)/graphs.pdf $(DIR)/table-team.html

summary: table
summary-incl-raw: all.iterations.incl.raw.csv
	@echo "Note: tabular presentation is not yet available for raw data." >&2
	@echo "See ./$< for the dataset itself." >&2

regen reset: clean view

view-%: config-exists-for-%
	$(MAKE_FROM_WILDCARD) view-team-visualisations

preset-%: config-exists-for-%
	@echo
	$(MAKE_FROM_WILDCARD) team-visualisations

ALL_PRESETS=$(shell ($(CONFIGS) || echo "1") | grep . -n | cut -d: -f1 | sed "s/.*/preset-&/")
all presets: $(ALL_PRESETS) table

table-team: $(DIR)/table-team.html
	open $<
table: table.html
	open $<
table-incl-raw: table-incl-raw.html
	open $<

zip: metrics.zip
metrics.zip: table.html lib */table-team.html */lib */graphs.pdf all.iterations.csv
	@rm -f $@
	zip -rq $@ $^

$(DIR)/table-team.html: table.r table.*.r common.r $(DIR)/augmented/metrics.csv
	@$(MAKE) docker-built
	@rm -f $@
	$(R_CUSTOM) ./$< $(ARGS)

table.html lib: table.r table.*.r common.r all.iterations.csv
	@$(MAKE) docker-built
	@rm -f $@
	$(R_CUSTOM) ./$<

table-incl-raw.html: table.r table.*.r common.r all.iterations.incl.raw.csv
	@$(MAKE) docker-built
	@rm -f $@
	@# TODO not ready for use yet
	$(R_CUSTOM) ./$< --include-raw-data

docker-built:
	@[ -n "$$(docker images $(DOCKER_TAG_R) -q)" ] || $(MAKE) build-docker

build-docker:
	@echo "Building docker image. This can take up to ten minutes." >&2
	docker build -t $(DOCKER_TAG_R) .

regen-all regen-presets reset-all reset-presets: clean presets summary
	@echo "Data for all teams is now available."
all.iterations.csv: combine.r $(shell ls *_*/augmented/iterations.full.csv 2>/dev/null || echo "$(DIR)/augmented/iterations.full.csv")
	./$<
	@echo "Combined data for all projects can now be found in: $@"
all.iterations.incl.raw.csv: combine.r $(shell ls *_*/augmented/iterations.full.csv 2>/dev/null || echo "$(DIR)/augmented/iterations.full.csv")
	./$< --include-raw-data
	@echo "See $@ for raw and change data. Be wary of comparing raw data between teams!"

$(DIR)/augmented/metrics.csv: combine.r $(DIR)/augmented/iterations.full.csv
	./$< $(ARGS) --include-raw-data

$(DIR)/augmented/iterations.full.csv: tidy.r tidy.functions.r $(DIR)/issues.csv
	@[ -d $(@D) ] || mkdir -p $(@D)
	$(R) ./$< $(ARGS)

graphs.pdf: $(DIR)/graphs.pdf
$(DIR)/graphs.pdf: graph.r $(DIR)/augmented/iterations.full.csv
	@$(MAKE) docker-built
	$(R_CUSTOM) ./$< $(ARGS)

$(DIR)/issues.csv: retrieve.py $(BASE_CONFIG)
	@[ -d $(DIR) ] || mkdir $(DIR)
	@echo "$(PROJECT)" >$(DIR)/.project
	@echo "$(BOARD)" >$(DIR)/.board
	./$< $(ARGS)

# Autocomplete helper rules
regen-car:
regen-pe:
regen-hp:
regen-paym:
regen-htdb:
config-car:
config-pe:
config-hp:
config-paym:
config-htdb:

config-exists-for-%:
	@[ -f configs.txt ] || (echo "Error: no configs.txt file found." >&2 && exit 1)
	@$(CONFIG_FROM_WILDCARD) >/dev/null || ( \
		([[ "$*" =~ ^[0-9]+$$ ]] \
			&& echo "Error: fewer than $* project(s) defined in configs.txt" >&2 \
			|| echo "Error: project '$*' not found in configs.txt" >&2) \
		&& exit 1)
regen-%: config-exists-for-%
	@echo "Recalculating board $$(\
		$(CONFIG_FROM_WILDCARD) | cut -d/ -f1) of project $$(\
		$(CONFIG_FROM_WILDCARD) | cut -d/ -f2)."
	$(MAKE_FROM_WILDCARD) -W .jira-url
config-%: config-exists-for-%
	@$(CONFIG_FROM_WILDCARD) | cut -d/ -f1 >.project
	@$(CONFIG_FROM_WILDCARD) | cut -d/ -f2 >.board
	@echo "Ready to produce data for board $$(cat .board) of project $$(cat .project)."

.email:
	@echo "Please enter the email address you use to log into Jira"
	@read email && echo "$$email" >$@

.apikey:
	@echo "Please enter your API key from JIRA, as per" >&1
	@echo "https://id.atlassian.com/manage-profile/security/api-tokens"
	@read apikey && echo "$$apikey" >$@

.project:
	@echo "Please enter your project name, e.g. Car, PE"
	@read project && echo "$$project" >$@

.board:
	@echo "Please enter the name of your primary Jira board, copied exactly"
	@echo "e.g. 'Car Data Extraction workstream' or 'PE board'"
	@read board && echo "$$board" >$@

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
	rm -rf *_*/ augmented/ **/lib **/*.pdf **/*.csv **/*.json **/*.html **/*.zip

cleaner:
	git clean -xdn -e .email -e .apikey -e .project -e .board

cleanest:
	git clean -xdf
