#!/usr/bin/env Rscript
source('tidy.functions.r')

issues <- read.csv('issues.csv')
transitions <- read.csv('transitions.csv')
iterations <- read.csv('iterations.csv')

# Join flattened transitions into the issues dataset
transitions <- flatten.transitions(transitions)
full.issues <- merge(issues, transitions, by.x='id', by.y='issue', all.x=T)

points <- analyse.estimates(full.issues)
full.issues <- reject.outlier.issues(full.issues, points)
# Re-calculate estimate metadata in case any issues' estimates were rejected
points <- analyse.estimates(full.issues)

# Restrict iterations to those that have finished
iterations <- subset(iterations, state == 'closed')
iterations$state <- NULL

iteration.stories <- calculate.iteration.stories(iterations, full.issues)
full.issues <- add.iteration.stories(iteration.stories, full.issues)
full.issues <- add.iteration.completions(iterations, full.issues)
iterations <- add.iteration.end.stats(iterations, full.issues)
iterations <- add.iteration.backlogs(iterations, full.issues)
iterations <- add.iteration.points(iteration.stories, full.issues)

iterations <- iterations[ order(iterations$start), ]
row.names(iterations) <- c(1:nrow(iterations))

# Calculate diffs for various stats across iterations
for (attr in c('stories', 'points')) {
  for (field in c('included', 'completed', 'backlog')) {
    data.col <- paste0(field,'.',attr)
    iterations <- calculate.change.for(data.col, iterations)
  }
}
iterations <- calculate.change.for('cycle.time', iterations)

full.issues <- merge(full.issues, points, by.x='points', by.y='estimate')

full.issues$delta <- full.issues$days.in.progress - full.issues$mean

calculate.cycle.time.deltas(full.issues)

# Write out all three relatively-intelligent datasets
full.issues.output <- full.issues
full.issues.output$in.iterations <- sapply(full.issues.output$in.iterations, paste, collapse=';')
write.csv(points, 'augmented/estimates.csv', row.names=FALSE)
write.csv(iterations, 'augmented/iterations.full.csv', row.names=FALSE)
write.csv(full.issues.output, 'augmented/issues.full.csv', row.names=FALSE)
write.csv(iteration.stories, 'augmented/iteration.stories.csv', row.names=FALSE)
