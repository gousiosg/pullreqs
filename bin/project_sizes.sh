#!/bin/bash
#
# (c) 2012 -- 2014 Georgios Gousios <gousiosg@gmail.com>
#
# BSD licensed, see LICENSE in top level dir
#

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

issues_closed=`echo "select count(*) from issue_events ie, issues i where ie.issue_id=i.id and ie.action='closed' and i.repo_id=$id;"|mysql -s -u gousios -p'G30rG10sGou' -h mcheck.st.ewi.tudelft.nl gousiosdb`

issues_open=$(($issues - $issues_closed))

issue_events=`echo "select count(*) from issue_events ie, issues i where ie.issue_id=i.id and i.repo_id=$id"|mysql -s -u gousios -p'G30rG10sGou' -h mcheck.st.ewi.tudelft.nl gousiosdb`

issue_comments=`echo "select count(*) from issue_comments ic, issues i where ic.issue_id=i.id and i.repo_id=$id"|mysql -s -u gousios -p'G30rG10sGou' -h mcheck.st.ewi.tudelft.nl gousiosdb`

project_members=`echo "select count(*) from project_members where repo_id=$id"|mysql -s -u gousios -p'G30rG10sGou' -h mcheck.st.ewi.tudelft.nl gousiosdb`

pull_requests=`echo "select count(*) from pull_requests where base_repo_id=$id;"|mysql -s -u gousios -p'G30rG10sGou' -h mcheck.st.ewi.tudelft.nl gousiosdb`

pr_merged=`echo "select count(pr.pullreq_id) from pull_requests pr where pr.base_repo_id = $id and exists(select prh.* from pull_request_history prh where prh.pull_request_id = pr.id and prh.action='closed') and exists(select prh.* from pull_request_history prh where prh.pull_request_id = pr.id and prh.action='merged')"|mysql -s -u gousios -p'G30rG10sGou' -h mcheck.st.ewi.tudelft.nl gousiosdb`

pr_ignored=`echo "select count(pr.pullreq_id) from pull_requests pr where pr.base_repo_id = $id and exists(select prh.* from pull_request_history prh where prh.pull_request_id = pr.id and prh.action='closed') and not exists(select prh.* from pull_request_history prh where prh.pull_request_id = pr.id and prh.action='merged')"|mysql -s -u gousios -p'G30rG10sGou' -h mcheck.st.ewi.tudelft.nl gousiosdb`

pr_open=`echo "select count(pr.pullreq_id) from pull_requests pr where pr.base_repo_id = $id and exists(select prh.* from pull_request_history prh where prh.pull_request_id = pr.id and prh.action='opened') and not exists(select prh.* from pull_request_history prh where prh.pull_request_id = pr.id and prh.action='closed')"|mysql -s -u gousios -p'G30rG10sGou' -h mcheck.st.ewi.tudelft.nl gousiosdb`

pull_request_comments=`echo "select count(*) from pull_requests pr, pull_request_comments prc where pr.base_repo_id=$id and prc.pull_request_id = pr.id;"|mysql -s -u gousios -p'G30rG10sGou' -h mcheck.st.ewi.tudelft.nl gousiosdb`

pull_request_events=`echo "select count(*) from pull_requests pr, pull_request_history prh where pr.base_repo_id=$id and prh.pull_request_id = pr.id;"|mysql -s -u gousios -p'G30rG10sGou' -h mcheck.st.ewi.tudelft.nl gousiosdb`

watchers=`echo "select count(*) from watchers where repo_id=$id"|mysql -s -u gousios -p'G30rG10sGou' -h mcheck.st.ewi.tudelft.nl gousiosdb`

echo "commits: $num_commits"
echo "forks: $num_forks"
echo "issues (open/closed): $issues ($issues_open/$issues_closed)"
echo "issue events: $issue_events"
echo "issue comments: $issue_comments"
echo "pull requests (open/merged/ignored): $pull_requests ($pr_open/$pr_merged/$pr_ignored)"
echo "pull request comments: $pull_request_comments"
echo "pull request events: $pull_request_events"

echo "project_members: $project_members"
echo "watchers/stargazers $watchers"


