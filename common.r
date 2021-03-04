
IGNORE.ALL.TASKS <- TRUE

# Metrics will be output in the same order as they appear here.
metric.descriptions <- list(
  days.in.progress = 'Number of days from a story first arriving in In Progress to finally being moved to Done',
  story.lifetime = 'Number of days from story creation to being moved to Done',
  estimate.correlation = 'Correlation coefficient between story-point estimate and days in progress',
  completed.points='Number of story points moved to Done during this iteration',
  included.points='Number of story points marked on Jira as part of this iteration',
  completed.stories='Number of cards moved to Done during this iteration',
  included.stories='Number of cards marked on Jira as part of this iteration',
  backlog.points = 'Total number of estimated story points in all cards not marked as Done',
  backlog.stories = 'Total number cards not marked as Done'
)

first.value.column <- function(df)
  head(which(sapply(names(df), function(col) col != 'order' && is.numeric(df[[col]]))), 1)
value.columns <- function(df)
  names(df)[ first.value.column(df):length(df) ]

# Output error stack traces
options(error = function() {
  sink(stderr())
  on.exit(sink(NULL))
  traceback(3, max.lines = 1L)
  if (!interactive()) {
    quit(status = 1)
  }
})
