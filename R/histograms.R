library(ggplot2)
library(grid)
library(reshape)

DF = read.csv(pipe("cut -f2-16 -d',' ~/Desktop/rails.csv"))

# Plot a list of plots using n columns 
multiplot <- function(plots, cols=1, title = "") {
  require(grid)

  numPlots = length(plots)
  print(plots[1])
  layout <- matrix(seq(1, cols * ceiling(numPlots/cols)),
                   ncol = cols, nrow = ceiling(numPlots/cols))

  if (numPlots==1) {
    print(plots[[1]])
  } else {
    # Set up the page
    grid.newpage()
    pushViewport(viewport(layout = grid.layout(nrow(layout), ncol(layout))))
    grid.text(title, gp=gpar(fontsize=12, col="grey"))
    
    # Make each plot, in the correct location
    for (i in 1:numPlots) {
      # Get the i,j matrix positions of the regions that contain this subplot
      matchidx <- as.data.frame(which(layout == i, arr.ind = TRUE))
      print(plots[[i]], vp = viewport(layout.pos.row = matchidx$row,
                                      layout.pos.col = matchidx$col))
    }
  }
}

plot.histogram <- function(data, var, title = var)
{
  p <- ggplot(data, aes_string(x = var)) 
  p <- p + geom_histogram(colour="black", fill="white") + scale_x_log10()
  p <- p + ggtitle(title)
  p
}

store <- function(f, name, where = "~/")
{
  pdf(paste(where, paste(name, "pdf", sep=".")))
  print(f)
  dev.off()
}

store.histogram <- function(data, name, where = "~/")
{
  store(plot.histogram(data, name), name, where)
}

plot.store.all_vars <- function(data, skip = 1, where = "~/") 
{
  lapply(colnames(data)[skip:length(colnames(data))], 
         function(x){store.histogram(data, x, where)})
}

plot.all_vars <- function(data, skip = 1) 
{
  lapply(colnames(data)[skip:length(colnames(data))],
         function(x){plot.histogram(data, x)})
}

plot.all_files <- function(dir = ".", skip = 1)
{
  dfs <- lapply(list.files(path = dir, pattern = "*.csv", full.names = T), 
                function(x){read.csv(pipe(paste("cut -f2-16 -d',' ", x)))})

  cols <- colnames(dfs[[1]])[skip:length(colnames(dfs[[1]]))]

  lapply(cols, function(x){
      items <- Filter(function(y){ x %in% colnames(y)}, dfs)
      multiplot(lapply(items, function(z){plot.histogram(z, x)}), 2)
      })
}

plot.all_files("~/Desktop/")

#multiplot(plot.all_vars(DF, skip = 9), cols = 2)
