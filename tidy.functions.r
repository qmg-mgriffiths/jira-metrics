
flatten.transitions <- function(transitions) {
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
  transitions
}

analyse.estimates <- function(issues) {
  if (all(is.na(issues$points))) {
    cat('Error: no stories appear to have estimates. Check retrieve.py or add some estimates.\n')
    quit(status=1)
  }
  points <- data.frame(
    estimate=as.factor(issues$points),
    cycle.time=issues$days.in.progress)
  points <- aggregate(. ~ estimate, points, c)
  points$count <- sapply(points$cycle.time, length)
  points$mean <- sapply(points$cycle.time, mean, na.rm=T)
  points$stddev <- sapply(points$cycle.time, sd, na.rm=T)
  points$interquartile <- sapply(points$cycle.time, IQR, na.rm=T)
  points$cycle.time <- NULL
  points
}

calculate.iteration.stories <- function(iterations, issues) {
  # Produce a standalone dataset linking issues with iterations they were included in
  iterations$issues <- sapply(iterations$issues, strsplit, ';')
  iteration.stories <- data.frame(
    issue=Reduce(c, iterations$issues),
    in.iterations=rep(iterations$name, sapply(iterations$issues, length)))
}

add.iteration.stories <- function(iteration.stories, issues) {
  iteration.stories.by.issue <- aggregate(. ~ issue, iteration.stories, c)
  iterations$issues <- NULL
  merge(issues, iteration.stories.by.issue, by.x='id', by.y='issue', all.x=T)
}

# Produce a standalone dataset linking issues with when they were completed
add.iteration.completions <- function(iterations, issues) {
  iteration.completions <- iterations[ c('name','start','end') ]
  iteration.completions <- merge(iteration.completions, issues[c('id', 'date.Done')], by=c())
  iteration.completions <- subset(iteration.completions, date.Done >= start & date.Done < end)
  iteration.completions <- iteration.completions[ c('id', 'name') ]
  names(iteration.completions) <- c('issue', 'completed.during')
  merge(issues, iteration.completions, by.x='id', by.y='issue', all.x=T)
}


add.iteration.end.stats <- function(iterations, issues) {
  iteration.end.stats <- issues[ c('days.in.progress', 'points', 'completed.during') ]
  names(iteration.end.stats) <- c('cycle.time', 'completed.points', 'iteration')
  iteration.end.stats <- aggregate(. ~ iteration, iteration.end.stats, c, simplify=FALSE)
  iteration.end.stats$completed.stories <- sapply(iteration.end.stats$completed.points, length)
  iteration.end.stats$completed.points <- sapply(iteration.end.stats$completed.points, sum, na.rm=T)
  iteration.end.stats$cycle.time <- sapply(iteration.end.stats$cycle.time, mean)
  iterations <- merge(iterations, iteration.end.stats, by.x='name', by.y='iteration', all.x=T)
  iterations[
    is.na(iterations$cycle.time),
    c('completed.points', 'completed.stories')
  ] <- 0
  iterations
}

add.iteration.backlogs <- function(iterations, issues) {
  iteration.backlog <- merge(iterations[c('name', 'end')], issues[c('id', 'created', 'status', 'points')])
  iteration.backlog <- subset(iteration.backlog, created < end & status != 'Done')
  iteration.backlog <- iteration.backlog[ c('name', 'points')]
  iteration.backlog <- aggregate(. ~ name, iteration.backlog, c, na.action=na.pass)
  iteration.backlog$stories <- sapply(iteration.backlog$points, length)
  iteration.backlog$points <- sapply(iteration.backlog$points, sum, na.rm=T)
  names(iteration.backlog) <- c('iteration', 'backlog.points', 'backlog.stories')
  merge(iterations, iteration.backlog, by.x='name', by.y='iteration')
}


add.iteration.points <- function(iteration.stories, issues) {
  iteration.points <- merge(
    iteration.stories[c('in.iterations', 'issue')],
    issues[c('id', 'points')],
    by.x='issue', by.y='id')
  iteration.points$issue <- NULL
  iteration.points <- aggregate(. ~ in.iterations, iteration.points, c, na.action=na.pass)
  iteration.points$stories <- sapply(iteration.points$points, length)
  iteration.points$points <- sapply(iteration.points$points, sum, na.rm=T)
  names(iteration.points) <- c('iteration', 'included.points', 'included.stories')
  iterations <- merge(iterations, iteration.points, by.x='name', by.y='iteration')
}


calculate.change.for <- function(data.col, iterations) {
  change.col <- paste0(data.col,'.change')

  change <- rep(NA, nrow(iterations))
  # Calculate diff between row n and n-1, as a percentage of row n's value
  change[-1] <-
    (iterations[-1, data.col] - iterations[-nrow(iterations), data.col]) /
    iterations[-nrow(iterations), data.col] * 100
  # Wipe any null values
  change[ is.nan(change) | is.infinite(change) ] <- NA

  iterations[[change.col]] <- change
  iterations
}
