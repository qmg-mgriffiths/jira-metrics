#!/usr/bin/env Rscript

library('formattable')
library('htmltools')
library('stringr')
source('table.functions.r')

# List of metrics for which high numbers are bad
swap.colours <- c('Backlog points', 'Backlog stories', 'Cycle time', 'Days in progress')

df <- read.csv('all.iterations.csv')

df$board <- NULL
df$iteration <- NULL
df <- reshape(df, direction='wide',
  timevar='project', v.names='value',
  idvar=c('metric', 'order'))

df <- df[!apply(df, 1, function(row) all(is.na(row[3:length(row)]))), ]

df$metric <- gsub('\\.change', ' (change)', df$metric)
df$metric <- gsub('\\.proportion', ' (proportion)', df$metric)
names(df) <- gsub('^value\\.', '', names(df))
df$metric <- str_to_sentence(gsub('\\.', ' ', df$metric))

df$order <- paste0(-df$order, ' ago')
df$order[ df$order == '0 ago' ] <- 'latest completed'
names(df)[ names(df) == 'order' ] <- 'Iteration age'
names(df)[ names(df) == 'metric' ] <- 'Metric'

row.names(df) <- NULL

tab <- formattable(df, align=c('r', 'r', rep('c', length(df)-2)),
  list(Metric=formatter("span", style=~ style(color = "grey", font.weight = "bold")),
        area(col = 3:ncol(df)) ~ percent.tile(df$Metric,
          c(swap.colours, gsub('$', ' (change)', swap.colours)))
))

export.formattable(tab, 'table.html')
