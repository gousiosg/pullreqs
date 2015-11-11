#!/bin/bash
#
# (c) 2012 -- 2014 Georgios Gousios <gousiosg@gmail.com>
#
# BSD licensed, see LICENSE in top level dir
#

parallel=1
dir='.'

usage()
{
  echo ""
	echo "Usage: $0 [-p num_processes] [-d output_dir] file"
  echo "Runs pull_req_data_extraction for an input file using multiple processes"
  echo "Options:"
  echo "  -p Number of processes to run in parallel (default: $parallel)"
  echo "  -d Output directory (default: $dir)"
  exit 1
}

while getopts "p:d:a:" o
do
	case $o in
	p)
    parallel=$OPTARG ;
    echo "Using $parallel processes";
    ;;
  d)
    dir=$OPTARG ;
    echo "Using $dir for output";
    ;;
  \?)
    echo "Invalid option: -$OPTARG" >&2 ;
    usage
    ;;
  :)
    echo "Option -$OPTARG requires an argument." >&2
    exit 1
    ;;
	esac
done

mkdir -p $dir

# Process remaining arguments after getopts as per:
# http://stackoverflow.com/questions/11742996/shell-script-is-mixing-getopts-with-positional-parameters-possible
if [ -z ${@:$OPTIND:1} ]; then
  usage
else
  input=${@:$OPTIND:1}
fi

parallel --progress --joblog parjobs --xapply -P $parallel ruby -Ibin bin/pull_req_data_extraction.rb -c config.yaml {1} {2} {3} 3 '1>' $dir/{1}@{2}.csv '2>' $dir/{1}@{2}.err ::: `cat $input|cut -f1 -d' '` ::: `cat $input|cut -f2 -d' '` ::: `cat $input|cut -f3 -d' '`
