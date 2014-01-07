source(file = "R/packages.R")
library(optparse)

# The following variables are exported to all scripts including this file
platform.sep = "/"

mysql.user =  "ghtorrent"
mysql.passwd = "ghtorrent"
mysql.db = "ghtorrent"
mysql.host = "127.0.0.1"

data.file.location = "data"
plot.location = "figs"
latex.location = "doc/icse/latex"
overall.dataset.stats = paste(data.file.location, "project-statistics.txt", 
                              sep  = platform.sep)
project.list = "projects.txt"

num.processes = 2

# Cmd-line parser
option_list <- list(
  make_option(c("-f", "--project-list"), default=project.list, dest = 'project.list',
              help = "File containing projects to load [default \"%default\"]"),

  make_option(c("-s", "--mysql-host"), default=mysql.host, dest = 'mysql.host',
              help = "MySQL host [default \"%default\"]"),
  make_option(c("-d", "--mysql-db"), default=mysql.db, dest = 'mysql.db',
              help = "MySQL database [default \"%default\"]"),
  make_option(c("-u", "--mysql-user"), default=mysql.user, dest = 'mysql.user',
              help = "MySQL user [default \"%default\"]"),
  make_option(c("-p", "--mysql-passwd"), default=mysql.passwd, dest = 'mysql.host',
              help = "MySQL password [default \"%default\"]"),

  make_option(c("-n", "--num-processes"), default = num.processes, 
              dest = 'num.processes', type = "integer",
              help = "Number of processes to use when running in parallel [default \"%default\"]")
)

args <- parse_args(OptionParser(option_list = option_list), 
                   print_help_and_exit = FALSE)

if (args$help) {
  parse_args(OptionParser(option_list = option_list))
}

project.list  = args$project.list
mysql.user    = args$mysql.user
mysql.passwd  = args$mysql.passwd
mysql.db      = args$mysql.db
mysql.host    = args$mysql.host
num.processes = args$num.processses
