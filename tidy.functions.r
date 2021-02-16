
IN.PROGRESS.COLUMNS <- c('In Progress', 'In Development')
DONE.COLUMNS <- c('Done')

pick.column <- function(transitions, candidates) {
  transitions$count <- 1
  transitions <- aggregate(. ~ to, transitions[c('to', 'count')], sum)
  transitions <- merge(transitions, data.frame(to=candidates))
  if (length(which(transitions$count > 0)) == 0) {
    cat("Error: no 'in progress' column detected. Check the list in tidy.functions.r.\n")
    quit(status=1)
  }
  transitions <- transitions[ order(-transitions$count), ]
  transitions[1, 'to']
}

# Find the IN.PROGRESS.COLUMN with the most stories assigned to it
pick.in.progress.column <- function(transitions)
  pick.column(transitions, IN.PROGRESS.COLUMNS)

pick.done.column <- function(transitions)
  pick.column(transitions, DONE.COLUMNS)

flatten.transitions <- function(transitions) {
  transitions <- transitions[ order(transitions$issue, transitions$date), ]
  transitions$from <- NULL

  in.progress <- pick.in.progress.column(transitions)
  done <- pick.done.column(transitions)

  # Group transitions by the column the story moved to
  transitions <- aggregate(. ~ issue + to, transitions, c)
  # We want the very last date a story ends up in Done, if there are several
  transitions[transitions$to == done, 'date'] <-
    sapply(transitions[transitions$to == done, 'date'], tail, 1)
  # For every other column, we want the first moment the story arrives there
  transitions$date <- sapply(transitions$date, head, 1)
  transitions$date <- as.POSIXct(transitions$date)

  # Flatten the data into one row per issue
  transitions <- reshape(transitions, direction='wide', timevar='to', idvar='issue', v.names='date')

  # Time between In Progress and Done is one of our more interesting stats
  transitions$days.in.progress <- as.numeric(
    (transitions[[paste0('date.', done)]] - transitions[[paste0('date.', in.progress)]]) / 86400)
  transitions
}

add.cycle.time <- function(issues, transitions) {
  issues$created <- as.POSIXct(issues$created)
  issues$cycle.time <- as.numeric(
    (issues[[paste0('date.', pick.done.column(transitions))]] - issues$created) / 86400)
  issues
}

analyse.estimates <- function(issues) {
  if (all(is.na(issues$points))) {
    cat('Error: no stories appear to have estimates. Check retrieve.py or add some estimates.\n')
    quit(status=1)
  }
  points <- data.frame(
    estimate=as.factor(issues$points),
    days.in.progress=issues$days.in.progress)
  points <- aggregate(. ~ estimate, points, c, na.action=na.pass)
  points$count <- sapply(points$days.in.progress, length)
  points$estimate.mean <- sapply(points$days.in.progress, mean, na.rm=T)
  points$estimate.stddev <- sapply(points$days.in.progress, sd, na.rm=T)
  points$estimate.interquartile <- sapply(points$days.in.progress, IQR, na.rm=T)
  points$days.in.progress <- NULL
  points
}

calculate.cycle.time.deltas <- function(full.issues) {
  deltas <- full.issues[ order(full.issues$iteration.end, full.issues$delta, decreasing=TRUE),
    c('id', 'points', 'days.in.progress', 'estimate.mean', 'delta', 'completed.during') ]
  deltas <- deltas[ deltas$delta & deltas$delta > 0, ]
  print(head(deltas, 10))
  invisible(deltas)
}


reject.outlier.issues <- function(issues, estimates) {
  if (length(which(!is.na(issues$points) & issues$points <= 0))) {
    cat(paste0("Warning: ignoring estimates of zero or below:\n"))
    print(issues[ !is.na(issues$points) & issues$points <= 0, c('id', 'points', 'days.in.progress') ])
    issues[ !is.na(issues$points) & issues$points <= 0, 'points' ] <- NA
  }
  outlier.issues <- merge(
    issues[c('id', 'days.in.progress', 'points')],
    estimates[c('estimate', 'estimate.mean', 'estimate.stddev')],
    by.x='points', by.y='estimate')
  outlier.issues <- subset(outlier.issues, days.in.progress > estimate.mean + (2 * estimate.stddev))
  if (nrow(outlier.issues) > 0) {
    cat(paste0("Warning: ignoring the estimates of the following extreme outliers:\n"))
    print(outlier.issues[ c('id', 'points', 'days.in.progress') ])
    issues[ full.issues$id %in% outlier.issues$id, 'points' ] <- NA
  }
  issues
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
  iteration.completions <- iteration.completions[ c('id', 'name', 'end') ]
  names(iteration.completions) <- c('issue', 'completed.during', 'iteration.end')
  merge(issues, iteration.completions, by.x='id', by.y='issue', all.x=T)
}


add.iteration.end.stats <- function(iterations, issues) {
  iteration.end.stats <- issues[ c('days.in.progress', 'cycle.time', 'points', 'completed.during') ]
  names(iteration.end.stats) <- c('days.in.progress', 'cycle.time', 'completed.points', 'iteration')
  iteration.end.stats <- aggregate(. ~ iteration, iteration.end.stats, c, simplify=FALSE, na.action=na.pass)
  iteration.end.stats$completed.stories <- sapply(iteration.end.stats$completed.points, length)
  iteration.end.stats$completed.points <- sapply(iteration.end.stats$completed.points, sum, na.rm=T)
  iteration.end.stats$cycle.time <- sapply(iteration.end.stats$cycle.time, mean, na.rm=T)
  iteration.end.stats$days.in.progress <- sapply(iteration.end.stats$days.in.progress, mean, na.rm=T)
  iterations <- merge(iterations, iteration.end.stats, by.x='name', by.y='iteration', all.x=T)
  iterations[
    is.na(iterations$cycle.time),
    c('completed.points', 'completed.stories')
  ] <- 0
  iterations$completed.stories.proportion <- iterations$completed.stories / iterations$included.stories
  iterations$completed.points.proportion <- iterations$completed.points / iterations$included.points
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
