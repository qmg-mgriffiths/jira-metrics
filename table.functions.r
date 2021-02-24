
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
    file.copy(path, file)
    unlink('lib/', recursive=TRUE)
    file.copy(gsub('/[^/]+$', '/lib', path), './', recursive=TRUE)
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
percent.tile <- function (partition=NULL, swap.colours=character()) {
  formatter("span", width='1em', style=function(x) {
    colours <- colour.range(x, partition=partition, swap.colours=swap.colours)
    style(display = "block",
          padding = "0 4px",
          `border-radius` = "4px",
          `background-color` = colours)
    },
    percent.format
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
