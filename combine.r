#!/usr/bin/env Rscript

iterations.files <- Sys.glob('*_*/augmented/iterations.full.csv')

args <- commandArgs(trailingOnly=TRUE)
CHANGES.ONLY <<- TRUE
if ('--include-raw-data' %in% args)
  CHANGES.ONLY <<- FALSE

if (length(iterations.files) == 0) {
  cat('No processed data files found. Try running via make.\n')
  quit(status=1)
}

iteration.details <- function(filename) {
  df <- read.csv(filename)
  base.dir <- gsub('/.*', '/', filename)
  project.file <- paste0(base.dir, '.project')
  board.file <- paste0(base.dir, '.board')
  if (!file.exists(project.file) || !file.exists(board.file)) {
    cat('No project metadata found in subdirectories. Try running via make.\n')
  }
  df$project <- readChar(project.file, file.info(project.file)$size - 1)
  df$board <- readChar(board.file, file.info(board.file)$size - 1)
  df$order <- seq(-nrow(df)+1, 0)
  df
}

tidy.iterations <- function(iterations) {
  iterations$project <- paste0(iterations$project, ': ', iterations$board)
  iterations$board <- NULL
  iterations <- iterations[ order(iterations$project, iterations$start), ]
  iterations$issues <- NULL
  iterations$start <- NULL
  iterations$end <- as.POSIXct(iterations$end)

  index.columns <- c('project','name','end', 'order')
  # Data columns will either be any non-index ones, or specifically .change ones
  data.columns <- setdiff(names(iterations), index.columns)
  if (CHANGES.ONLY)
    data.columns <- names(iterations)[grep('\\.change$', names(iterations))]
  # Take only the most relevant/comparable columns
  iterations[ c(index.columns, data.columns) ]
}

reshape.iterations <- function(iterations) {
  # Wide format is (project, var1.change, var2.change, ...)
  # Long format is (project, metric, value)
  value.field <- ifelse(CHANGES.ONLY, 'change', 'value')
  fields <- setdiff(names(iterations), c('project', 'name', 'end', 'order'))
  long.format <- reshape(iterations, direction="long",
		timevar="metric", v.names=value.field,
    idvar=c('project', 'order'),
		varying=fields, times=fields)
  long.format[ grep('\\.change', long.format$metric), value.field] <- round(
    long.format[ grep('\\.change', long.format$metric), value.field],
    1)
  if (CHANGES.ONLY)
    long.format$metric <- gsub('\\.change$', '', long.format$metric)
  row.names(long.format) <- 1:nrow(long.format)
  names(long.format)[2:4] <- c('iteration', 'iteration.end', 'order')

  # Take a subset of columns, and order the results
  long.format <- long.format[ order(long.format$metric, -long.format$order, long.format$project), ]
  long.format[ c('metric', 'project', 'iteration', 'iteration.end', value.field)]
}


iterations <- iteration.details(iterations.files[1])
for (f in iterations.files[-1]) {
  iterations <- rbind(iterations, iteration.details(f))
}

iterations <- tidy.iterations(iterations)
iterations <- reshape.iterations(iterations)

outpath <- ifelse(CHANGES.ONLY, 'all.iterations.csv', 'all.iterations.incl.raw.csv')
write.csv(iterations, outpath, row.names=FALSE)
