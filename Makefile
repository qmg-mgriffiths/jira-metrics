
view: graphs.pdf
	open $<

augmented/iteration.completions.csv: tidy.r issues.csv
	@[ -d $(@D) ] || mkdir $(@D)
	./$<

graphs.pdf: graph.r augmented/iteration.completions.csv
	./$<

issues.csv: retrieve.py .apikey
	./$<

.apikey:
	@echo "Please retrieve an API key from Jira and put it in ./$@" >&1
	@echo "See https://id.atlassian.com/manage-profile/security/api-tokens"
	@exit 1

clean:
	rm -rf augmented/ *.pdf

cleaner:
	git clean -xdf -e .apikey

cleanest:
	git clean -xdf
