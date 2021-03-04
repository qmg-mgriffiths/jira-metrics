
# Move data for a subset of metrics into a new column for per-team data
reshape.per.team.subset <- function(subset.df, type='value') {
  conditional <- if (type == 'value')
    !grepl('\\.change', subset.df$metric) & !grepl('\\.proportion', subset.df$metric)
  else
    grepl(paste0('\\.', type,'$'), subset.df$metric)
  if (type == 'change')
    conditional <- conditional & !grepl(paste0('\\.proportion.change$'), subset.df$metric)
  subset.df <- subset(subset.df, conditional)
  subset.df$metric <- gsub('\\.change', '', subset.df$metric)
  subset.df$metric <- gsub('\\.proportion', '', subset.df$metric)
  subset.df$board <- NULL
  subset.df$iteration <- NULL
  subset.df$type <- type
  subset.df <- reshape(subset.df, direction='wide',
    timevar='type',
    v.names='value',
    idvar=c('project', 'metric', 'order'))
  subset.df
}

# Reshape a long metric/value dataset to have columns for different metric types
reshape.per.team <- function(df) {
  change.df <- reshape.per.team.subset(df, 'change')
  proportion.df <- reshape.per.team.subset(df, 'proportion')
  proportion.change.df <- reshape.per.team.subset(df, 'proportion.change')
  df <- reshape.per.team.subset(df)
  df <- merge(df, change.df, by=c('project', 'metric', 'order'), all=T, suffixes=c('', '.change'))
  df <- merge(df, proportion.df, by=c('project', 'metric', 'order'), all=T, suffixes=c('', '.proportion'))
  df <- merge(df, proportion.change.df, by=c('project', 'metric', 'order'), all=T, suffixes=c('', '.proportion.change'))
  df
}

# Reshape a long metric/value dataset to have columns for different teams
reshape.across.teams <- function(df) {
  df$board <- NULL
  df$iteration <- NULL
  reshape(df, direction='wide',
    timevar='project', v.names='value',
    idvar=c('metric', 'order'))
}

# Reshape a long metric/value dataset to have one row per metric/iteration
reshape.dataset <- function(df) {
  if (!is.na(TEAM))
    reshape.per.team(df)
  else
    reshape.across.teams(df)
}


tidy.names.per.team <- function(df) {
  names(df)[ match(
    c('value.value', 'value.change', 'value.proportion', 'value.proportion.change'),
    names(df))
  ] <- c('Value', 'Change', 'Proportion', 'Prop. change')
  df
}

# Order the dataset appropriately
order.df <- function(df)
  df[ order(df$metric, -df$order), ]

# Prettify column headers and other text data
tidy.names <- function(df) {
  if (!is.na(TEAM))
    df <- tidy.names.per.team(df)

  df$metric <- gsub('\\.change', ' (change)', df$metric)
  df$metric <- gsub('\\.proportion', ' (proportion)', df$metric)
  names(df) <- gsub('^value\\.', '', names(df))
  df$metric <- str_to_sentence(gsub('\\.', ' ', df$metric))

  df$order <- paste0(-df$order, ' ago')
  df$order[ df$order == '0 ago' ] <- 'latest completed'
  names(df)[ names(df) == 'order' ] <- 'Iteration age'
  names(df)[ names(df) == 'metric' ] <- 'Metric'

  row.names(df) <- NULL
  df
}

# Remove rows for which all columns' values are empty
remove.empty.rows <- function(df) {
  cols <- value.columns(df)
  df[!apply(df, 1, function(row) all(is.na(row[cols])) ), ]
}
