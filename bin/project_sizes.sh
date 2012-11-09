#!/bin/bash

if [ -z $1 ] || [ -z $2 ]; then
  echo "usage: project_sizes owner repo"
  exit 1 
fi

MYSQL="mysql -q -u gousios -p'G30rG10sGou' -h mcheck.st.ewi.tudelft.nl gousiosdb"

id=`echo "select p.id from projects p, users u where u.id = p.owner_id and p.name='$2' and u.login='$1';"|mysql -s -u gousios -p'G30rG10sGou' -h mcheck.st.ewi.tudelft.nl gousiosdb`

echo "id: $id"

num_commits=`echo "select count(*) from commits where project_id=$id;"|mysql -s -u gousios -p'G30rG10sGou' -h mcheck.st.ewi.tudelft.nl gousiosdb`

num_forks=`echo "select count(*) from forks where forked_from_id=$id;"|mysql -s -u gousios -p'G30rG10sGou' -h mcheck.st.ewi.tudelft.nl gousiosdb`

pull_reqs=`echo "select count(*) from pull_requests where base_repo_id=$id;"|mysql -s -u gousios -p'G30rG10sGou' -h mcheck.st.ewi.tudelft.nl gousiosdb`

issues=`echo "select count(*) from issues where repo_id=$id;"|mysql -s -u gousios -p'G30rG10sGou' -h mcheck.st.ewi.tudelft.nl gousiosdb`

issue_events=`echo "select count(*) from issue_events ie, issues i where ie.issue_id=i.id and i.repo_id=$id"|mysql -s -u gousios -p'G30rG10sGou' -h mcheck.st.ewi.tudelft.nl gousiosdb`

issue_comments=`echo "select count(*) from issue_comments ic, issues i where ic.issue_id=i.id and i.repo_id=$id"|mysql -s -u gousios -p'G30rG10sGou' -h mcheck.st.ewi.tudelft.nl gousiosdb`

project_members=`echo "select count(*) from project_members where repo_id=$id"|mysql -s -u gousios -p'G30rG10sGou' -h mcheck.st.ewi.tudelft.nl gousiosdb`

echo "commits: $num_commits"
echo "forks: $num_forks"
echo "issues: $issues"
echo "issue events: $issue_events"
echo "issue comments: $issue_comments"
echo "project_members: $project_members"

