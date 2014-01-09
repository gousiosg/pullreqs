#!/bin/bash
#
# (c) 2012 -- 2014 Georgios Gousios <gousiosg@gmail.com>
#
# BSD licensed, see LICENSE in top level dir
#

parallel=1
dir='.'
ip=`/sbin/ifconfig |grep "inet add"|grep -v "127.0.0"|head -n 1|cut -f2 -d':'|cut -f1 -d' '`

usage()
{
  echo ""
	echo "Usage: $0 [-p num_processes] [-d output_dir] file"
  echo "Runs pull_req_data_extraction for an input file using multiple processes"
  echo "Options:"
  echo "  -p Number of processes to run in parallel (default: $parallel)"
  echo "  -d Output directory (default: $dir)"
  echo "  -a IP address to use for outgoing requests (default: $ip)"
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
  a)
    ip=$OPTARG ;
    echo "Using $ip for requests";
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

# Process remaining arguments after getopts as per:
# http://stackoverflow.com/questions/11742996/shell-script-is-mixing-getopts-with-positional-parameters-possible
if [ -z ${@:$OPTIND:1} ]; then
  usage
else
  input=${@:$OPTIND:1}
fi

cat $input |
grep -v "^#"|
while read pr; do
  name=`echo $pr|cut -f1,2 -d' '|tr ' ' '@'`
  echo "ruby -Ibin bin/pull_req_data_extraction.rb -a $ip -c config.yaml $pr |grep -v '^[DUG]' |grep -v Overrid | grep -v 'unknown\ header'|grep -v '^$' 1>$dir/$name.csv 2>$dir/$name.err"
done | xargs -P $parallel -Istr sh -c str

