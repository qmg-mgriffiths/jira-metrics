
IGNORE.ALL.TASKS <- TRUE

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
