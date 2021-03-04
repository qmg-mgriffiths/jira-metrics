
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

# Addresses situation where team uses one In Progress column then switches to another
# => i.e. where data is missing from one column, try loading it from another
join.in.progress.columns <- function(full.issues) {
  cols <- intersect(paste0('date.', IN.PROGRESS.COLUMNS), names(full.issues))
  updated.issues <- full.issues
  for (col in cols) {
    updated.issues[[col]] <- apply(full.issues[cols], 1, function(row, col) {
      if (!is.na(row[[col]]))
        return(row[[col]])
      alternative <- which(!is.na(unlist(row)))
      # If zero or 2+ other columns have data, we don't have a clear alternative
      if (length(alternative) != 1)
        return(NA)
      row[[alternative]]
    }, col)
    updated.issues[[col]] <- as.POSIXct(updated.issues[[col]])
  }
  updated.issues
}

flatten.transitions <- function(transitions) {
  transitions <- transitions[ order(transitions$issue, transitions$date), ]
  transitions$from <- NULL
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
  transitions
}

add.cycle.times <- function(issues, transitions) {
  # Time between In Progress and Done is one of our more interesting stats
  done <- pick.done.column(transitions)
  in.progress <- pick.in.progress.column(transitions)
  issues$days.in.progress <- as.numeric(
    (issues[[paste0('date.', done)]] - issues[[paste0('date.', in.progress)]]) / 86400)

  straight.to.done <- which(!is.na(issues[['date.Done']]) & is.na(issues[['days.in.progress']]))
  if (length(straight.to.done) > 0) {
    cat(paste0("Warning: ",length(straight.to.done)," cards went straight to Done without being In Progress first, including:\n"))
    straight.to.done <- straight.to.done[ order(issues[straight.to.done, 'date.Done'], decreasing=T) ]
    print(head(issues[straight.to.done, c('id', 'type', 'date.Done')]))
  }
  issues$created <- as.POSIXct(issues$created)
  issues$story.lifetime <- as.numeric(
    issues[[paste0('date.', pick.done.column(transitions))]] - issues$created)
  issues
}

analyse.estimates.for.iteration <- function(issues, iteration=NA) {
  if (!is.na(iteration)) {
    issues <- subset(issues, completed.during == iteration)
  }
  points <- data.frame(
    estimate=as.factor(issues$points),
    days.in.progress=issues$days.in.progress)
  points <- aggregate(. ~ estimate, points, c, na.action=na.pass, simplify=F)
  points <- points[ !sapply(points$days.in.progress, function(days) all(is.na(days))), ]
  points$iteration <- rep(iteration, nrow(points))
  points$count <- sapply(points$days.in.progress, length)
  points$estimate.mean <- sapply(points$days.in.progress, mean, na.rm=T)
  points$estimate.stddev <- sapply(points$days.in.progress, sd, na.rm=T)
  points$estimate.interquartile <- sapply(points$days.in.progress, IQR, na.rm=T)
  points$days.in.progress <- NULL
  points
}

analyse.estimates <- function(issues) {
  if (all(is.na(issues$points))) {
    cat('Error: no stories appear to have estimates. Check retrieve.py or add some estimates.\n')
    quit(status=1)
  }
  estimates <- analyse.estimates.for.iteration(issues)
  for (iteration in setdiff(unique(issues$completed.during), NA)) {
    estimates <- rbind(estimates, analyse.estimates.for.iteration(issues, iteration))
  }
  estimates
}

calculate.cycle.time.deltas <- function(full.issues) {
  deltas <- full.issues[ order(full.issues$iteration.end, full.issues$delta, decreasing=TRUE),
    c('id', 'points', 'days.in.progress', 'estimate.mean', 'delta', 'completed.during') ]
  deltas <- deltas[ !is.na(deltas$delta) & deltas$delta > 0, ]
  cat("A few of the slowest stories relative to their estimate class:\n")
  # TODO some IDs may be duplicated if they were Done on iteration transition day
  deltas <- subset(deltas, !duplicated(deltas$id))
  row.names(deltas) <- deltas$id
  print(head(deltas[-1], 10))
  invisible(deltas)
}


reject.outlier.issues <- function(issues, estimates) {
  estimates <- subset(estimates, is.na(iteration))
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
    row.names(outlier.issues) <- outlier.issues$id
    print(outlier.issues[ c('points', 'days.in.progress') ])
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
  iteration.end.stats <- issues[ c('days.in.progress', 'story.lifetime', 'points', 'completed.during') ]
  names(iteration.end.stats) <- c('days.in.progress', 'story.lifetime', 'completed.points', 'iteration')
  iteration.end.stats <- aggregate(. ~ iteration, iteration.end.stats, c, simplify=FALSE, na.action=na.pass)
  iteration.end.stats$completed.stories <- sapply(iteration.end.stats$completed.points, length)
  iteration.end.stats$completed.points <- sapply(iteration.end.stats$completed.points, sum, na.rm=T)
  iteration.end.stats$story.lifetime <- sapply(iteration.end.stats$story.lifetime, mean, na.rm=T)
  iteration.end.stats$days.in.progress <- sapply(iteration.end.stats$days.in.progress, mean, na.rm=T)
  iterations <- merge(iterations, iteration.end.stats, by.x='name', by.y='iteration', all.x=T)
  iterations[
    is.na(iterations$story.lifetime),
    c('completed.points', 'completed.stories')
  ] <- 0
  iterations$completed.stories.proportion <- iterations$completed.stories / iterations$included.stories * 100
  iterations$completed.points.proportion <- iterations$completed.points / iterations$included.points * 100
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

add.iteration.correlations <- function(iterations, issues, estimates) {
  iterations$estimate.correlation <- sapply(iterations$name, function(iteration.name) {
    iteration.issues <- subset(issues, completed.during == iteration.name)
    iteration.issues <- iteration.issues[ iteration.issues$points %in% estimates$estimate, ]
    if (nrow(iteration.issues) == 0)
      return(NA)
    cor(iteration.issues$points, iteration.issues$days.in.progress, use='pairwise.complete.obs')
  })
  iterations
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
