R=docker run -i --rm -v $$PWD:/host -w /host r-base:4.0.0
R_GGPLOT=docker run -i --rm -v $$PWD:/host -w /host rocker/tidyverse:4.0.0

BASE_CONFIG=.apikey .email .jira-url
PROJECT_CONFIG=.project .board
PROJECT=$(shell cat .project 2>/dev/null)
BOARD=$(shell cat .board 2>/dev/null)
DIR=$(shell echo "$(PROJECT) $(BOARD)" | tr '[A-Z]' '[a-z]' | tr -d '-' | sed -E "s/ +/_/g")
ARGS=$(shell [ -n "$(PROJECT)" ] && [ -n "$(BOARD)" ] && echo "'$(PROJECT)' '$(BOARD)' '$(DIR)'")
PRESET_MAKE=$(MAKE) $(shell $(CONFIGS) | tail -n +$* | head -1 \
	| sed -E "s|^([^/]+)/(.+)|PROJECT='\\1' BOARD='\\2'|g")

CONFIGS=cat configs.txt | sed -E 's/ *\#.*//' | grep .

view-preset-1:

preset-%:
	@echo
	$(PRESET_MAKE) graphs.pdf

presets: $(shell $(CONFIGS) | grep . -n | cut -d: -f1 | sed "s/.*/preset-&/")

view-%:
	$(PRESET_MAKE) view
view: $(DIR)/graphs.pdf
	open $<

regen: clean view

$(DIR)/augmented/iterations.full.csv: tidy.r tidy.functions.r $(DIR)/issues.csv
	@[ -d $(@D) ] || mkdir -p $(@D)
	$(R) ./$< $(ARGS)

graphs.pdf: $(DIR)/graphs.pdf
$(DIR)/graphs.pdf: graph.r $(DIR)/augmented/iterations.full.csv
	$(R_GGPLOT) ./$< $(ARGS)

$(DIR)/issues.csv: retrieve.py $(BASE_CONFIG)
	@[ -d $(DIR) ] || mkdir $(DIR)
	./$< $(ARGS)

regen-platform: config-platform clean view
config-platform:
	echo "https://policy-expert.atlassian.net/" >.jira-url
	echo "PE" >.project
	echo "PE board" >.board

regen-car: config-car clean view
config-car:
	echo "https://policy-expert.atlassian.net/" >.jira-url
	echo "Car" >.project
	echo "Car Data Extraction workstream" >.board

regen-home-product: config-home-product clean view
config-home-product:
	echo "https://policy-expert.atlassian.net/" >.jira-url
	echo "HP" >.project
	echo "Home Brand Scrum board" >.board

regen-home-tech-debt-bau: config-home-tech-debt-bau clean view
config-home-tech-debt-bau:
	echo "https://policy-expert.atlassian.net/" >.jira-url
	echo "HTDB" >.project
	echo "Home Non-Brand Scrum Board" >.board

regen-home-gdpr: config-home-gdpr clean view
config-home-gdpr:
	echo "https://policy-expert.atlassian.net/" >.jira-url
	echo "HGDPR" >.project
	echo "Home GDPR Scrum board" >.board

regen-payments: config-payments clean view
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

cleanish:
	rm -rf augmented/ *.pdf

clean:
	rm -rf *_*/ augmented/ *.pdf *.csv *.json

cleaner:
	git clean -xdn -e .email -e .apikey -e .project -e .board

cleanest:
	git clean -xdf
