#!/usr/bin/env Rscript

library('ggplot2')

args <- commandArgs(trailingOnly=TRUE)

pdf(paste0(args[3], '/graphs.pdf'))

iterations <- read.csv(paste0(args[3], '/augmented/iterations.full.csv'))
full.issues <- read.csv(paste0(args[3], '/augmented/issues.full.csv'))
estimates <- read.csv(paste0(args[3], '/augmented/estimates.csv'))
iteration.stories <- read.csv(paste0(args[3], '/augmented/iteration.stories.csv'))

singleton.estimates <- estimates$count <= 1 & is.na(estimates$iteration)
if (length(which(singleton.estimates)) > 0) {
  singleton.estimates <- estimates[singleton.estimates, c('estimate', 'count')]
  cat(paste('Warning: omitting', nrow(singleton.estimates), 'estimate value(s) used by just one story:\n'))
  row.names(singleton.estimates) <- NULL
  print(singleton.estimates)
  estimates <- subset(estimates, ! estimate %in% singleton.estimates$estimate)
}
estimate.config <- list(
  theme(
      legend.position='top',
      plot.title=element_text(hjust = 0.5),
      plot.subtitle=element_text(hjust = 0.5)),
  guides(colour=guide_legend(nrow=2, byrow=TRUE)),
  ylab('Days in progress'),
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

iteration.change.graph <- c(iteration.graph, list(
  theme(axis.title.y=element_text()),
  ylab('Percentage increase'),
  coord_cartesian(ylim=c(
    max(-100, min(iterations[
      names(iterations)[ grepl('\\.change$', names(iterations)) ]
    ], na.rm=T)),
    min(100, max(iterations[
      names(iterations)[ grepl('\\.change$', names(iterations)) ]
    ], na.rm=T))
  ))))

# Plot evolution of stories across sprints
ggplot(iterations[-1,], aes(x=start)) + iteration.change.graph +
  ggtitle('Backlog evolution across sprints') +
  line.and.smooth('backlog.stories.change', 'Stories in backlog') +
  line.and.smooth('backlog.points.change', 'Story points in backlog')

ggplot(iterations[-1,], aes(x=start)) + iteration.change.graph +
  ggtitle('In-progress time evolution across sprints') +
  line.and.smooth('story.lifetime.change', 'Full story lifetime in days') +
  line.and.smooth('days.in.progress.change', 'Days in development')

ggplot(iterations[-1,], aes(x=start)) + iteration.change.graph +
  ggtitle('Proportional story completion across sprints') +
  line.and.smooth('completed.stories.proportion.change', 'Percentage of included stories completed') +
  line.and.smooth('completed.points.proportion.change', 'Percentage of included story points completed')

ggplot(iterations[-1,], aes(x=start)) + iteration.change.graph +
  ggtitle('Raw story completion across sprints') +
  line.and.smooth('included.stories.change', 'Stories in sprint') +
  line.and.smooth('included.points.change', 'Story points in sprint') +
  line.and.smooth('completed.stories.change', 'Stories completed') +
  line.and.smooth('completed.points.change', 'Story points completed')

ggplot(iterations[-1,], aes(x=start)) + iteration.change.graph +
  ggtitle('All sprint change stats') +
  line.and.smooth('included.stories.change', 'Stories in sprint') +
  line.and.smooth('included.points.change', 'Story points in sprint') +
  line.and.smooth('backlog.stories.change', 'Stories in backlog') +
  line.and.smooth('backlog.points.change', 'Story points in backlog') +
  line.and.smooth('completed.stories.change', 'Stories completed') +
  line.and.smooth('completed.points.change', 'Story points completed') +
  line.and.smooth('story.lifetime.change', 'Cycle time in days') +
  line.and.smooth('days.in.progress.change', 'Days in development')

estimate.boxplot <- function(issues, iteration.name, all.breaks) {
  issues <- subset(issues, (is.na(iteration.name) | completed.during == iteration.name))
  issues <- issues[c('points', 'days.in.progress')]
  issues <- subset(issues, !is.na(points) & !is.na(days.in.progress))
  issues <- issues[order(issues$points, issues$days.in.progress), ]
  issues <- issues[ issues$points %in% estimates$estimate, ]
  correlation <- suppressWarnings(
    tryCatch(
      cor(issues$points, issues$days.in.progress, use='pairwise.complete.obs'),
      error=function(x) NA))
  correlation <- ifelse(is.na(correlation), 'N/A', round(correlation, 2))
  if (nrow(issues) == 0)
    return(invisible())
  issues <- merge(issues, all.breaks, by.x='points', by.y='estimate', all=T, suffixes=c('','.breaks'))
  g <- ggplot(issues, aes(x=points, y=days.in.progress)) +
    estimate.config +
    labs(
      title='Estimate accuracy, by stories',
      subtitle=paste0(
        ifelse(is.na(iteration.name), 'All iterations', iteration.name),
        ' (correlation: ', correlation, ')')) +
    scale_x_continuous(breaks=all.breaks$estimate) +
    geom_boxplot(aes(group=points), na.rm=T) +
    geom_point(na.rm=T) +
    geom_smooth(method='lm', formula= y ~ x, na.rm=T, se=length(which(!is.na(issues$days.in.progress))) > 2)
  print(g)
  invisible()
}

estimate.bar.graph <- function(estimates, iteration.name, all.breaks) {
  iteration.estimates <- subset(estimates,
    (is.na(iteration.name) & is.na(iteration)) | iteration == iteration.name)
  if (nrow(iteration.estimates) == 0 || all(is.na(iteration.estimates$estimate.mean))) {
    cat(paste('Warning: skipping estimate accuracy graph for',
      ifelse(is.na(iteration.name), 'all sprints',iteration.name),
      'for lack of data.\n'))
    return(invisible())
  }
  iteration.estimates <- merge(iteration.estimates, all.breaks, by='estimate', all=T, suffixes=c('','.all'))
  iteration.estimates[ is.na(iteration.estimates$count), 'count' ] <- 0
  iteration.estimates[ is.na(iteration.estimates$estimate.mean), 'estimate.mean' ] <- 0
  g <- ggplot(iteration.estimates, aes(x=estimate)) +
    theme(axis.text.x=element_text(angle=30, hjust=1)) +
    estimate.config + ggtitle('Estimate accuracy, by estimate') +
    labs(subtitle=ifelse(is.na(iteration.name), 'Across all iterations', iteration.name)) +
    suppressWarnings(scale_x_continuous(
      breaks=iteration.estimates$estimate,
      labels=paste0(iteration.estimates$estimate, ' (×',iteration.estimates$count,')'))) +
    geom_bar(aes(y=estimate.mean, fill='Average development time'), stat='identity', na.rm=T) +
    geom_bar(aes(y=estimate.mean.all, fill='Average development time'), colour='grey', alpha=0.15, stat='identity') +
    geom_point(aes(y=estimate.interquartile, shape='Interquartile range'), size=3, na.rm=T) +
    geom_point(aes(y=estimate.stddev, shape='Standard deviation'), size=3, na.rm=T)
  print(g)
  invisible()
}

all.breaks <- unique(estimates[ is.na(estimates$iteration), c('estimate', 'count', 'estimate.mean')])
for (iteration.name in c(NA, rev(iterations$name))) {
  estimate.boxplot(full.issues, iteration.name, all.breaks)
}
for (iteration.name in c(NA, rev(iterations$name))) {
  estimate.bar.graph(estimates, iteration.name, all.breaks)
}


# Plot stories per sprint
ggplot(iterations, aes(x=start)) +
  iteration.graph +
  ggtitle('Stories per sprint') +
  line.and.smooth('story.lifetime', 'Story lifetime in days') +
  line.and.smooth('days.in.progress', 'Days in development') +
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
