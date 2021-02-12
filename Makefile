R=docker run -it --rm -v $$PWD:/host -w /host r-base:4.0.0
R_GGPLOT=docker run -it --rm -v $$PWD:/host -w /host rocker/tidyverse:4.0.0

CONFIG=.apikey .board .email .project .jira-url

view: graphs.pdf
	open $<

regen: clean view

augmented/iterations.full.csv: tidy.r tidy.functions.r issues.csv
	@[ -d $(@D) ] || mkdir $(@D)
	$(R) ./$<

graphs.pdf: graph.r augmented/iterations.full.csv
	$(R_GGPLOT) ./$<

issues.csv: retrieve.py $(CONFIG)
	./$<

regen-platform: config-platform view
config-platform:
	echo "https://policy-expert.atlassian.net/" >.jira-url
	echo "PE" >.project
	echo "PE board" >.board

regen-car: config-car view
config-car:
	echo "https://policy-expert.atlassian.net/" >.jira-url
	echo "Car" >.project
	echo "Car Data Extraction workstream" >.board

regen-home-product: config-home-product view
config-home-product:
	echo "https://policy-expert.atlassian.net/" >.jira-url
	echo "HP" >.project
	echo "Home Brand Scrum board" >.board

regen-home-tech-debt-bau: config-home-tech-debt-bau view
config-home-tech-debt-bau:
	echo "https://policy-expert.atlassian.net/" >.jira-url
	echo "HTDB" >.project
	echo "Home Non-Brand Scrum Board" >.board

regen-home-gdpr: config-home-gdpr view
config-home-gdpr:
	echo "https://policy-expert.atlassian.net/" >.jira-url
	echo "HGDPR" >.project
	echo "GDPR Kanban board" >.board

regen-payments: config-payments view
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

cleanish:
	rm -rf augmented/ *.pdf

clean:
	rm -rf augmented/ *.pdf *.csv *.json

cleaner:
	git clean -xdn -e .email -e .apikey -e .project -e .board

cleanest:
	git clean -xdf
