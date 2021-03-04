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

# Turning configs.txt into meaningful parameters
CONFIGS=cat configs.txt | sed -E 's/ *\#.*//' | grep .
ALL_PRESETS=$(shell $(CONFIGS) | grep . -n | cut -d: -f1 | sed "s/.*/preset-&/")
PRESET_MAKE=$(MAKE) $(shell $(CONFIGS) | tail -n +$* | head -1 \
	| sed -E "s|^([^/]+)/(.+)|PROJECT='\\1' BOARD='\\2'|g")

view: $(DIR)/graphs.pdf $(DIR)/table-team.html
	open $^

summary: table
summary-incl-raw: all.iterations.incl.raw.csv
	@echo "Note: tabular presentation is not yet available for raw data." >&2
	@echo "See ./$< for the dataset itself." >&2

regen reset: clean view

view-%:
	$(PRESET_MAKE) view

preset-%:
	@echo
	$(PRESET_MAKE) graphs.pdf

all presets: $(ALL_PRESETS)

table-team: $(DIR)/table-team.html
	open $<
table: table.html
	open $<
table-incl-raw: table-incl-raw.html
	open $<

zip: metrics.zip
metrics.zip: table.html table-team.html lib */graphs.pdf all.iterations.csv
	@rm -f $@
	zip -rq $@ $^

$(DIR)/table-team.html: table.r table.*.r common.r all.iterations.incl.raw.csv
	@$(MAKE) docker-built
	@rm -f $@
	$(R_CUSTOM) ./$< $(ARGS)

table.html lib: table.r table.*.r common.r all.iterations.csv
	@$(MAKE) docker-built
	@rm -f $@
	$(R_CUSTOM) ./$<

table-incl-raw.html: table.r table.*.r common.r all.iterations.csv
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
all.iterations.csv: combine.r $(shell ls *_*/augmented/iterations.full.csv 2>/dev/null || echo "presets")
	./$<
	@echo "Combined data for all projects can now be found in: $@"
all.iterations.incl.raw.csv: combine.r $(shell ls *_*/augmented/iterations.full.csv 2>/dev/null || echo "presets")
	./$< --include-raw-data
	@echo "See $@ for raw and change data. Be wary of comparing raw data between teams!"

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

regen-platform:
	$(MAKE) PROJECT=PE BOARD='PE board' clean-dir view
config-platform:
	echo "https://policy-expert.atlassian.net/" >.jira-url
	echo "PE" >.project
	echo "PE board" >.board

regen-car:
	$(MAKE) PROJECT=Car BOARD='Car Data Extraction workstream' clean-dir view
config-car:
	echo "https://policy-expert.atlassian.net/" >.jira-url
	echo "Car" >.project
	echo "Car Data Extraction workstream" >.board

regen-home-product:
	$(MAKE) PROJECT=HP BOARD='Home Brand Scrum board' clean-dir view
config-home-product:
	echo "https://policy-expert.atlassian.net/" >.jira-url
	echo "HP" >.project
	echo "Home Brand Scrum board" >.board

regen-home-tech-debt-bau:
	$(MAKE) PROJECT=HTDB BOARD='Home Non-Brand Scrum Board' clean-dir view
config-home-tech-debt-bau:
	echo "https://policy-expert.atlassian.net/" >.jira-url
	echo "HTDB" >.project
	echo "Home Non-Brand Scrum Board" >.board

regen-home-gdpr:
	$(MAKE) PROJECT=HGDPR BOARD='Home GDPR Scrum board' clean-dir view
config-home-gdpr:
	echo "https://policy-expert.atlassian.net/" >.jira-url
	echo "HGDPR" >.project
	echo "Home GDPR Scrum board" >.board

regen-payments:
	$(MAKE) PROJECT=PAYM BOARD='Scrum World - Payments' clean-dir view
config-payments:
	echo "https://policy-expert.atlassian.net/" >.jira-url
	echo "PAYM" >.project
	echo "Scrum World - Payments" >.board

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
	rm -rf *_*/ augmented/ *.pdf *.csv *.json

cleaner:
	git clean -xdn -e .email -e .apikey -e .project -e .board

cleanest:
	git clean -xdf
