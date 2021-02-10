#!/usr/bin/env Rscript

issues <- read.csv('issues.csv')
transitions <- read.csv('transitions.csv')
iterations <- read.csv('iterations.csv')

transitions <- transitions[ order(transitions$issue, transitions$date), ]
transitions$from <- NULL

# Group transitions by the column the story moved to
transitions <- aggregate(. ~ issue + to, transitions, c)
# We want the very last date a story ends up in Done, if there are several
transitions[transitions$to == 'Done', 'date'] <- sapply(transitions[transitions$to == 'Done', 'date'], tail, 1)
# For every other column, we want the first moment the story arrives there
transitions$date <- sapply(transitions$date, head, 1)
transitions$date <- as.POSIXct(transitions$date)

# Flatten the data into one row per issue
transitions <- reshape(transitions, direction='wide', timevar='to', idvar='issue', v.names='date')

# Time between In Progress and Done is one of our more interesting stats
transitions$days.in.progress <- as.numeric((transitions$date.Done - transitions[['date.In Progress']]) / 86400)

# Restrict to only stories which are complete
# transitions <- subset(transitions, !is.na(date.Done))
#  => not having ever reached Done should of course return NA

# TODO then write a README and Makefile, with a docker (or dojo) command to
#  run the script using trovediary/r-base

# Join flattened transitions into the issues dataset
full.issues <- merge(issues, transitions, by.x='id', by.y='issue', all.x=T)

# Restrict iterations to those that have finished
iterations <- subset(iterations, state == 'closed')
iterations$state <- NULL

# Produce a standalone dataset linking issues with iterations they were included in
iterations$issues <- sapply(iterations$issues, strsplit, ';')
iteration.stories <- data.frame(
  issue=Reduce(c, iterations$issues),
  in.iterations=rep(iterations$name, sapply(iterations$issues, length)))
iteration.stories.by.issue <- aggregate(. ~ issue, iteration.stories, c)
iterations$issues <- NULL

# Produce a standalone dataset linking issues with when they were completed
iteration.completions <- iterations[ c('name','start','end') ]
iteration.completions <- merge(iteration.completions, full.issues[c('id', 'date.Done')], by=c())
iteration.completions <- subset(iteration.completions, date.Done >= start & date.Done < end)
iteration.completions <- iteration.completions[ c('id', 'name') ]
names(iteration.completions) <- c('issue', 'completed.during')

iteration.points <- merge(iteration.stories[c('in.iterations', 'issue')], full.issues[c('id', 'points')], by.x='issue', by.y='id')
iteration.points$issue <- NULL
iteration.points <- aggregate(. ~ in.iterations, iteration.points, c, na.action=na.pass)
iteration.points$stories <- sapply(iteration.points$points, length)
iteration.points$points <- sapply(iteration.points$points, sum, na.rm=T)
iterations <- merge(iterations, iteration.points, by.x='name', by.y='in.iterations')
iterations

# Join the two new datasets into one behemoth
full.issues <- merge(full.issues, iteration.stories.by.issue, by.x='id', by.y='issue')
full.issues <- merge(full.issues, iteration.completions, by.x='id', by.y='issue')

# Write out all three relatively-intelligent datasets
full.issues.output <- full.issues
full.issues.output$in.iterations <- sapply(full.issues.output$in.iterations, paste, collapse=';')
write.csv(iterations, 'augmented/iterations.full.csv', row.names=FALSE)
write.csv(full.issues.output, 'augmented/issues.full.csv', row.names=FALSE)
write.csv(iteration.stories, 'augmented/iteration.stories.csv', row.names=FALSE)
write.csv(iteration.completions, 'augmented/iteration.completions.csv', row.names=FALSE)
