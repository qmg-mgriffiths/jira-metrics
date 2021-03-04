
#' FROM https://github.com/renkun-ken/formattable/issues/26
#' Export a Formattable as PNG, PDF, or JPEG
#'
#' @param f A formattable.
#' @param file Export path with extension .png, .pdf, or .jpeg.
#' @param width Width specification of the html widget being exported.
#' @param height Height specification of the html widget being exported.
#' @param background Background color specification.
#' @param delay Time to wait before taking webshot, in seconds.
#'
#' @importFrom formattable as.htmlwidget
#' @importFrom htmltools html_print
#' @importFrom webshot webshot
#'
#' @export
export.formattable <- function(f, file, width = "100%", height = NULL,
                               background = "white", delay = 0.2) {
  w <- as.htmlwidget(f, width = width, height = height)
  path <- html_print(w, background = background, viewer = NULL)
  if (grepl('\\.html$', file)) {
    dir <- gsub('[^/]+$', '', file)
    file.copy(path, file)
    unlink(paste0(dir,'lib/'), recursive=TRUE)
    file.copy(gsub('/[^/]+$', '/lib', path), paste0('./',dir), recursive=TRUE)
    return(invisible())
  }
  url <- paste0("file:///", gsub("\\\\", "/", normalizePath(path)))
  library('webshot')
  webshot(url,
          file = file,
          selector = ".formattable_widget",
          delay = delay)
}

# Turn a range of numbers into a block of HTML cells
cell.format <- function (partition=NULL, swap.colours=character(), output.format=percent.format) {
  formatter("span", width='1em', style=function(x) {
    colours <- colour.range(x, partition=partition, swap.colours=swap.colours)
    style(display = "block",
          padding = "0 4px",
          `border-radius` = "4px",
          `background-color` = colours)
    },
    output.format
  )}

# Turn a block of numbers into HTML colours, optionally partitioned by a metric
colour.range <- function(x,
  very.bad='#CD5E77', mildly.bad='#F6E9E9',
  very.good='#71CA97', mildly.good='#DEF7E9',
  neutral='white', partition=NULL, swap.colours=character()) {
  # For a multi-row block, recurse on each column
  if (length(dim(x)) > 1) {
    return(apply(x, 2, colour.range,
      very.bad, mildly.bad, very.good, mildly.good,
      neutral, partition, swap.colours))
  }
  # If no partition specified, just go from worst as lowest to best as highest
  if (length(partition) == 0) {
    return(ramp(x, very.bad, very.good))
  }
  out <- rep(neutral, length(x))
  # Treat each partition (e.g. each metric) individually for colour scaling
  for (p in unique(partition)) {
    xs <- partition == p & !is.na(x)
    if (p %in% swap.colours) {
      out[xs & x < 0]  <- ramp(x[xs & x < 0], very.good, mildly.good)
      out[xs & x > 0]  <- ramp(x[xs & x > 0], mildly.bad, very.bad)
    } else {
      out[xs & x < 0]  <- ramp(x[xs & x < 0], very.bad, mildly.bad)
      out[xs & x > 0]  <- ramp(x[xs & x > 0], mildly.good, very.good)
    }
  }
  out
}

# Turn a range of numbers into a range of HTML colour strings between the provided bounds
ramp <- function(x, from, to) {
  if (length(x) == 0)
    return(character())
  x <- as.numeric(x)
  norm <- normalize(x)
  ramp <- colorRamp(c(from, to))
  components <- t(ramp(norm))
  rownames(components) <- c('red','green','blue')
  mode(components) <- 'integer'
  csscolor(components)
}

# Turn a number like 0.5342 into a nice percentage
percent.format <- function(x) percent(x / 100, digits=1)

identity.format <- function(x) round(x, 1)

# Produce a formattable object for an individual team's data
draw.table.per.team <- function(df) {
  if (length(unique(df$project)) == 1)
    df$project <- NULL
  value.col <- first.value.column(df)
  formattable(df, align=c(rep('r', 3), rep('c', length(df)-3)),
    list(
      Description=formatter("span", style=~ style(color = "grey", font.style = "italic")),
      Metric=formatter("span", style=~ style(color = "grey", font.weight = "bold")),
      area(col = value.col) ~ cell.format(df$Metric, swap.colours, identity.format),
      area(col = (value.col+1):ncol(df)) ~ cell.format(df$Metric,
        c(swap.colours, gsub('$', ' (change)', swap.colours)))
    ))
}

add.metric.descriptions <- function(df) {
  descriptions <- data.frame(
    metric=names(metric.descriptions),
    Description=as.character(metric.descriptions),
    metric.order=c(1:length(metric.descriptions)))

  proportion.descriptions <- descriptions
  proportion.descriptions$metric <- paste0(proportion.descriptions$metric, '.proportion')
  proportion.descriptions$metric.order <- proportion.descriptions$metric.order + 0.25
  proportion.descriptions$Description <- paste0(
    proportion.descriptions$Description,
    ', as a proportion of those included in the iteration')
  descriptions <- rbind(descriptions, proportion.descriptions)

  change.descriptions <- descriptions
  change.descriptions$metric <- paste0(change.descriptions$metric, '.change')
  change.descriptions$metric.order <- change.descriptions$metric.order + 0.5
  change.descriptions$Description <- paste0(
    change.descriptions$Description,
    ' (percent change from last iteration)')
  descriptions <- rbind(descriptions, change.descriptions)
  descriptions <- subset(descriptions, !duplicated(metric))

  df <- merge(df, descriptions, by='metric', all.x=T)
  df <- df[ c('Description', 'metric.order', setdiff(names(df), c('Description', 'metric.order'))) ]
  df <- order.df(df)
  df[ duplicated(df$Description), 'Description' ] <- NA
  df[ is.na(df$Description), 'Description' ] <- ''
  df
}

# Produce a formattable object for comparable data between teams
draw.table.across.teams <- function(df)
  formattable(df, align=c('r', 'r', rep('c', length(df)-2)),
    list(
      Description=formatter("span", style=~ style(color = "grey", font.style = "italic")),
      Metric=formatter("span", style=~ style(color = "grey", font.weight = "bold")),
      area(col = first.value.column(df):ncol(df)) ~ cell.format(df$Metric,
        c(swap.colours, gsub('$', ' (change)', swap.colours)))
    ))

# Produce a formattable object as appropriate
draw.table <- function(df) {
  if (!is.na(TEAM))
    draw.table.per.team(df)
  else
    draw.table.across.teams(df)
}
