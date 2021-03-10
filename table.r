#!/usr/bin/env Rscript

library('formattable')
library('htmltools')
library('stringr')
source('common.r')
source('table.manipulation.r')
source('table.presentation.r')

args <- commandArgs(trailingOnly=TRUE)
TEAM <- ifelse(length(args) >= 2,
  paste0(args[1], ': ', args[2]),
  NA)

# List of metrics for which high numbers are bad
swap.colours <- c('Backlog points', 'Backlog stories', 'Cycle time', 'Days in progress', 'Story lifetime')

INCL.RAW.DATA <- '--include-raw-data' %in% args

df <- if (!is.na(TEAM)) {
  read.csv(paste0(args[3], '/augmented/metrics.csv'))
} else if (INCL.RAW.DATA) {
  cat("Warning: all data is currently output as percentages, even when absolute.\n")
  read.csv('all.iterations.incl.raw.csv')
} else {
  read.csv('all.iterations.csv')
}
if (nrow(df) == 0) {
  cat(paste0('No data found', ifelse(is.na(TEAM), '', paste0(' for ', TEAM)),'\n'))
  quit(status=1)
}



df <- reshape.dataset(df)

df <- remove.empty.rows(df)

df <- add.metric.descriptions(df)

df <- tidy.names(df)

tab <- draw.table(df)

outpath <- if(length(args) >= 3) {
  paste0(args[3], '/table-team.html')
} else if (INCL.RAW.DATA) {
  'table-incl-raw.html'
} else {
  'table.html'
}
export.formattable(tab, outpath)
