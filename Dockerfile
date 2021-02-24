FROM r-base:4.0.0

RUN /usr/bin/env Rscript -e "install.packages(\
  c('ggplot2', 'formattable', 'htmltools', 'stringr'), \
  repos='https://cran.ma.imperial.ac.uk/')"
