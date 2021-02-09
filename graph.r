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
transitions <- subset(transitions, !is.na(date.Done))

# Join flattened transitions into the issues dataset
raw <- merge(issues, transitions, by.x='id', by.y='issue', all.x=T)


# Add in iterations
iterations <- subset(iterations, state == 'closed')
iterations$state <- NULL
names(iterations) <- c('iteration', 'iteration.start', 'iteration.end')
raw <- merge(raw, iterations, by=c())
raw <- subset(raw, date.Done >= iteration.start & date.Done < iteration.end)

# Write out the full, combined dataset
write.csv(raw, 'combined.csv', row.names=FALSE)


# Group things by iteration, getting ready to plot it
iteration.stats <- raw[ c('days.in.progress', 'points', 'iteration', 'iteration.end') ]
iteration.stats <- aggregate(. ~ iteration, iteration.stats, c, simplify=FALSE)
iteration.stats$iteration.end <- sapply(iteration.stats$iteration.end, head, 1)
iteration.stats$iteration.end <- as.Date(iteration.stats$iteration.end)
iteration.stats$days.in.progress <- sapply(iteration.stats$days.in.progress, as.numeric)
iteration.stats$points <- sapply(iteration.stats$points, as.numeric)

# Produce a single nice plottable dataset
analysis <- data.frame(
  iteration=iteration.stats$iteration,
  iteration.start=iteration.stats$iteration.end,
  cycle.time=sapply(iteration.stats$days.in.progress, mean),
  stories=sapply(iteration.stats$days.in.progress, length),
  points=sapply(iteration.stats$points, sum)
)


library('ggplot2')
pdf('graphs.pdf')

# Plot the data in a simple way
ggplot(analysis, aes(x=iteration.start)) +
  theme(axis.text.x=element_text(angle=30, hjust=1),
      axis.title.y=element_blank(),
      legend.position='top',
      plot.title=element_text(hjust = 0.5)) +
  xlab('Iteration start date') +
  ggtitle('First draft of iteration stats') +
  scale_x_date(breaks=analysis$iteration.start, labels=analysis$iteration) +
  geom_line(aes(y=cycle.time, colour='Cycle time in days')) +
  geom_line(aes(y=stories, colour='Stories completed')) +
  geom_vline(aes(xintercept=iteration.start), size=0.1) +
  geom_line(aes(y=points, colour='Story points completed'))

ggplot(raw[!is.na(raw$points),], aes(x=points, y=days.in.progress)) +
  xlab('Story points (estimated)') +
  ylab('Days in progress') +
  labs(
    title='We have the worst estimates',
    subtitle=paste0('Correlation value: ',
      round(cor(raw$points, raw$days.in.progress, use='pairwise.complete.obs'), 2))) +
  theme(legend.position='top',
      plot.title=element_text(hjust = 0.5),
      plot.subtitle=element_text(hjust = 0.5)) +
  geom_point() +
  geom_smooth(method='lm', formula= y ~ x)
