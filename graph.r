#!/usr/bin/env Rscript

library('ggplot2')
pdf('graphs.pdf')

iterations <- read.csv('augmented/iterations.full.csv')
full.issues <- read.csv('augmented/issues.full.csv')
iteration.stories <- read.csv('augmented/iteration.stories.csv')
iteration.completions <- read.csv('augmented/iteration.completions.csv')
full.issues$in.iterations <- sapply(full.issues$in.iterations, strsplit, ';')

# Group things by iteration, getting ready to plot it
iteration.end.stats <- full.issues[ c('days.in.progress', 'points', 'completed.during') ]
names(iteration.end.stats) <- c('cycle.time', 'points.completed', 'iteration')
iteration.end.stats <- aggregate(. ~ iteration, iteration.end.stats, c, simplify=FALSE)
iteration.end.stats$stories.completed <- sapply(iteration.end.stats$points.completed, length)
iteration.end.stats$points.completed <- sapply(iteration.end.stats$points.completed, sum, na.rm=T)
iteration.end.stats$cycle.time <- sapply(iteration.end.stats$cycle.time, mean)


iteration.stats <- merge(iterations, iteration.end.stats, by.x='name', by.y='iteration')
iteration.stats$end <- sapply(iteration.stats$end, head, 1)
iteration.stats$end <- as.Date(iteration.stats$end)
iteration.stats$start <- as.Date(iteration.stats$start)

# Plot the data in a simple way
ggplot(iteration.stats, aes(x=start)) +
  theme(axis.text.x=element_text(angle=30, hjust=1),
      axis.title.y=element_blank(),
      legend.position='top',
      plot.title=element_text(hjust = 0.5)) +
  guides(colour=guide_legend(nrow=2, byrow=TRUE)) +
  xlab('Iteration start date') +
  ggtitle('Second draft of iteration stats') +
  scale_x_date(breaks=iteration.stats$start, labels=iteration.stats$name) +
  geom_line(aes(y=points, colour='Story points in sprint')) +
  geom_line(aes(y=points, colour='Story points in sprint')) +
  geom_line(aes(y=cycle.time, colour='Cycle time in days')) +
  geom_line(aes(y=stories, colour='Stories in sprint')) +
  geom_line(aes(y=stories.completed, colour='Stories completed')) +
  geom_line(aes(y=points.completed, colour='Story points completed')) +
  geom_vline(aes(xintercept=start), size=0.1)

ggplot(full.issues[!is.na(full.issues$points),], aes(x=points, y=days.in.progress)) +
  xlab('Story points (estimated)') +
  ylab('Days in progress') +
  labs(
    title='Accuracy of estimates',
    subtitle=paste0('Correlation: ',
      round(
        cor(
          full.issues$points,
          full.issues$days.in.progress,
          use='pairwise.complete.obs'),
        2))) +
  theme(legend.position='top',
      plot.title=element_text(hjust = 0.5),
      plot.subtitle=element_text(hjust = 0.5)) +
  geom_point() +
  geom_smooth(method='lm', formula= y ~ x)
