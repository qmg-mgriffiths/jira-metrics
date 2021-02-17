#!/usr/bin/env Rscript
source('tidy.functions.r')

args <- commandArgs(trailingOnly=TRUE)
issues <- read.csv(paste0(args[3], '/issues.csv'))
transitions <- read.csv(paste0(args[3], '/transitions.csv'))
iterations <- read.csv(paste0(args[3], '/iterations.csv'))

# Join flattened transitions into the issues dataset
full.issues <- merge(
  issues,
  flatten.transitions(transitions),
  by.x='id', by.y='issue', all.x=T)

full.issues <- add.cycle.time(full.issues, transitions)

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

iterations <- add.iteration.backlogs(iterations, full.issues)
iterations <- add.iteration.points(iteration.stories, full.issues)
iterations <- add.iteration.end.stats(iterations, full.issues)

iterations <- iterations[ order(iterations$start), ]
row.names(iterations) <- c(1:nrow(iterations))

# Calculate diffs for various stats across iterations
for (attr in c('stories', 'points')) {
  for (field in c('included', 'completed', 'backlog')) {
    data.col <- paste0(field,'.',attr)
    iterations <- calculate.change.for(data.col, iterations)
  }
}
iterations <- calculate.change.for('completed.stories.proportion', iterations)
iterations <- calculate.change.for('completed.points.proportion', iterations)
iterations <- calculate.change.for('days.in.progress', iterations)
iterations <- calculate.change.for('cycle.time', iterations)

full.issues <- merge(full.issues, points, by.x='points', by.y='estimate')

full.issues$delta <- full.issues$days.in.progress - full.issues$estimate.mean

calculate.cycle.time.deltas(full.issues)

# Write out all three relatively-intelligent datasets
full.issues.output <- full.issues
full.issues.output$in.iterations <- sapply(full.issues.output$in.iterations, paste, collapse=';')
write.csv(points, paste0(args[3], '/augmented/estimates.csv'), row.names=FALSE)
write.csv(iterations, paste0(args[3], '/augmented/iterations.full.csv'), row.names=FALSE)
write.csv(full.issues.output, paste0(args[3], '/augmented/issues.full.csv'), row.names=FALSE)
write.csv(iteration.stories, paste0(args[3], '/augmented/iteration.stories.csv'), row.names=FALSE)
