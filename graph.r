#!/usr/bin/env Rscript

library('ggplot2')
pdf('graphs.pdf')

iterations <- read.csv('augmented/iterations.full.csv')
full.issues <- read.csv('augmented/issues.full.csv')
estimates <- read.csv('augmented/estimates.csv')
iteration.stories <- read.csv('augmented/iteration.stories.csv')

if (length(which(estimates$count <= 1))) {
  cat(paste('Warning: omitting',length(which(estimates$count <= 1)), 'estimate value(s) used by just one story:\n'))
  print(subset(estimates[ c('estimate', 'count') ], count <= 1))
  estimates <- subset(estimates, count > 1)
}
estimate.config <- list(
  theme(axis.text.x=element_text(angle=30, hjust=1),
      legend.position='top',
      plot.title=element_text(hjust = 0.5),
      plot.subtitle=element_text(hjust = 0.5)),
  guides(colour=guide_legend(nrow=2, byrow=TRUE)),
  scale_x_continuous(
    breaks=estimates$estimate,
    labels=paste0(estimates$estimate, ' (×',estimates$count,')')),
  ylab('Actual cycle time'),
  xlab('Story points estimated'))


# Deserialise complicated data types
full.issues$in.iterations <- sapply(full.issues$in.iterations, strsplit, ';')
iterations$end <- as.Date(iterations$end)
iterations$start <- as.Date(iterations$start)

# Calculate correlations and gradients for fields, just for interest.
corrs <- data.frame('field'=character(), 'gradient'=numeric(), 'correlation'=numeric())
for (type in c('stories', 'points')) {
  for (col in c('included', 'completed', 'backlog')) {
    corrs <- rbind(corrs, data.frame(
      field=paste0(col,'.',type),
      type=type,
      gradient=coef(lm(
        as.formula(paste0(col, '.', type, ' ~ end')),
        iterations
      ))[2],
      correlation=cor(
        iterations[[ paste0(col, '.', type) ]],
        as.numeric(iterations$end) )
    ))
  }
}
row.names(corrs) <- corrs$field

corr.graph <- ggplot(corrs, aes(x=field)) +
  geom_point(aes(y=gradient, colour=type)) +
  geom_point(aes(y=correlation, colour=type))
# print(corr.graph)
print(corrs[c('gradient', 'correlation')])

line.and.smooth <- function(variable, colour) list(
  geom_line(aes(y=.data[[variable]], colour=colour), size=0.3, na.rm=T),
  geom_smooth(
    aes(y=.data[[variable]], colour=colour),
    method='lm', linetype='dashed', formula = y ~ x, se=FALSE, na.rm=T))

# Line graph config
iteration.graph <- list(
  theme(axis.text.x=element_text(angle=30, hjust=1),
      axis.title.y=element_blank(),
      legend.position='top',
      plot.title=element_text(hjust = 0.5)),
  guides(colour=guide_legend(nrow=2, byrow=TRUE)),
  scale_x_date(breaks=iterations$start, labels=iterations$name),
  xlab('Iteration'),
  geom_vline(aes(xintercept=start), size=0.1))

# Plot evolution of stories across sprints
ggplot(iterations[-1,], aes(x=start)) +
  iteration.graph +
  ggtitle('Evolution of stories across sprints') +
  theme(axis.title.y=element_text()) + ylab('Percentage increase') +
  line.and.smooth('included.stories.change', 'Stories in sprint') +
  # line.and.smooth('included.points.change', 'Story points in sprint') +
  line.and.smooth('backlog.stories.change', 'Stories in backlog') +
  line.and.smooth('backlog.points.change', 'Story points in backlog')

# stddev per story point
# => boxplots

# Plot evolution of completion of stories across sprints
ggplot(iterations[-1,], aes(x=start)) +
  iteration.graph +
  ggtitle('Evolution of story completion across sprints') +
  theme(axis.title.y=element_text()) + ylab('Percentage increase') +
  line.and.smooth('cycle.time.change', 'Cycle time in days') +
  line.and.smooth('completed.stories.change', 'Stories completed') +
  line.and.smooth('completed.points.change', 'Story points completed')

# Plot stories per sprint
ggplot(iterations, aes(x=start)) +
  iteration.graph +
  ggtitle('Stories per sprint') +
  line.and.smooth('cycle.time', 'Cycle time in days') +
  line.and.smooth('included.stories', 'Stories in sprint') +
  line.and.smooth('included.points', 'Story points in sprint') +
  line.and.smooth('completed.stories', 'Stories completed') +
  line.and.smooth('completed.points', 'Story points completed')

# Plot backlog size across sprints
ggplot(iterations, aes(x=start)) +
  iteration.graph +
  ggtitle('Evolving backlog size') +
  line.and.smooth('backlog.stories', 'Stories in backlog') +
  line.and.smooth('backlog.points', 'Story points in backlog')

points <- full.issues[c('points', 'days.in.progress')]
points <- subset(points, !is.na(points) & !is.na(days.in.progress))
points <- points[order(points$points, points$days.in.progress), ]
points <- points[ points$points %in% estimates$estimate, ]
ggplot(points, aes(x=points, y=days.in.progress)) +
  estimate.config +
  labs(
    title='Estimate accuracy, by stories',
    subtitle=paste0('Correlation: ',
      round(
        cor(
          points$points,
          points$days.in.progress,
          use='pairwise.complete.obs'),
        2))) +
  geom_boxplot(aes(group=points)) +
  geom_point() +
  geom_smooth(method='lm', formula= y ~ x)

ggplot(estimates, aes(x=estimate)) +
  estimate.config + ggtitle('Estimate accuracy, by estimate') +
  geom_bar(aes(y=mean, fill='Average cycle time'), stat='identity') +
  geom_point(aes(y=interquartile, shape='Interquartile range'), size=3, na.rm=T) +
  geom_point(aes(y=stddev, shape='Standard deviation'), size=3, na.rm=T)
