#!/usr/bin/env bash

rsync -av gousiosg@23.97.131.71:/mnt/pullreqs/data/* .
rsync -av gousiosg@65.52.148.249:/mnt/pullreqs/data/* .
rsync -av gousiosg@dutiht.st.ewi.tudelft.nl:~/pullreqs/data/* .
rsync -av gousiosg@dutihr.st.ewi.tudelft.nl:~/pullreqs/data/* .
rsync -av gousiosg@dutiap.st.ewi.tudelft.nl:~/pullreqs/data/* .

