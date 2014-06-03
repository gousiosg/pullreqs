# Pullreq Analysis

An analysis and report of how pull requests work for Github

## Installation and configuration

You only need the following in case you want to regenerate (or generate more)
the data files used for the analysis. The data files used in the various
papers can be found in `data/*.csv`.

Make sure that Ruby 1.9.3 is installed on your machine. You can 
try [RVM](https://rvm.io/), if it is not. Then, it should suffice
to do:

<pre>
gem install bundler
bundle install
gem install mysql2
</pre>

The executable commands in this project inherit functionality from the
[GHTorrent](https://github.com/gousiosg/github-mirror) libraries. 
To work, they need the GHTorrent MongoDB data and a recent version of
the GHTorrent MySQL database. For that, you may use the data from
[ghtorrent.org](http://ghtorrent.org).

In addition to command specific arguments, the commands use the same
`config.yaml` file for specific connection details to external systems.  You
can find a template `config.yaml` file
[here](https://github.com/gousiosg/github-mirror/blob/master/config.yaml.tmpl).
The analysis scripts only are only interested in the connection details for
MySQL and MongoDB, and the location of a temporary directory 
(the `cache_dir` directory).

## Analyzing the data

The data analysis consists of two steps:

* Generating intermediate data files
* Analyzing data files with R

####Generating intermediate files

To produce the required data files, first run the
`bin/pull_req_data_extraction.rb` script like so:

```bash
  ruby -Ibin bin/pull_req_data_extraction.rb -c config.yaml owner repo lang
```

where: 
* `owner` is the project owner
* `repo` is the name of the repository
* `lang` is the main repository language as reported by Github. At the moment, only `ruby`, `java`, `python` and `scala` projects can produce fully compatible data files.

The projects we analyzed in each paper are included in the `projects.txt`
file included in each paper directory. 
The projects that are commented out were excluded for reasons identified in each paper. 

The data extraction script extracts several variables
for each pull request and prints to `STDOUT` a comma-separated
line for each pull request using the following fields: 

* `pull_req_id`: The database id for the pull request
* `project_name`: The name of the project (same for all lines)
* `github_id`: The Github id for the pull request. Can be used to see the
actual pull request on Github using the following URL:
`https://github.com/#{owner}/#{repo}/pull/#{github_id}`
* `created_at`: The epoch timestamp of the creation date of the pull request
* `merged_at`: The epoch timestamp of the merge date of the pull request
* `closed_at`: The epoch timestamp of the closing date of the pull request
* `lifetime_minutes`: Number of minutes between the creation and the close of
the pull request
* `mergetime_minutes`: Number of minutes between the creation and the merge of
the pull request
* `merged_using`: The heuristic used to identify the merge action. The field can have the following values
    * `github`: The merge button was used for merging
    * `commits_in_master`: One of the pull request commits appears in the project's master branch
    * `fixes_in_commit`: The PR was closed by a commit and the commit SHA is in the project's master
    * `commit_sha_in_comments`: The PR's discussion includes a commit SHA and matches the following regexp `merg(?:ing|ed)|appl(?:ying|ied)|pull[?:ing|ed]|push[?:ing|ed]|integrat[?:ing|ed]`
    * `merged_in_comments`: One of the last 3 PR comments matches the above regular expression
    * `unknown`: The pull request cannot be identified as merged
* `conflict`: Boolean, true if the pull request comments include the word conflict
* `forward_links`: Boolean, true if the pull request comments include a link to
a newer pull request
* `team_size`: The number of people that had committed to the
     repository directly (not through pull requests) in the period
     `(merged_at - 3 months, merged_at)`
* `num_commits`: Number of commits included in the pull request
* `num_commit_comments`: Number of code review comments
* `num_issue_comments`: Number of discussion comments
* `num_comments`: Total number of comments (`num_commit_comments + num_issue_comments`)
* `num_participants`: Number of people participating in pull request discussions
* `files_added`: Files added by the pull request
* `files_deleted`: Files deleted by the pull request
* `files_modified`: Files modified by the pull request
* `files_changed`: Total number of files changed (added, modified, deleted) by the pull request
* `src_files`: Number of src files touched by the pull request
* `doc_files`: Number of documentation files touched by the pull request
* `other_files`: Number of other (non src/doc) files touched by the pull request 
* `perc_external_contribs`: % of commits commit from pull requests up to one month
before the start of this pull request
* `total_commits_last_month`: Number of commits
* `main_team_commits_last_month`: Number of commits to the repository during
the last month, excluding the commits coming from this and other pull requests
* `sloc`: Number of executable lines of code in the main project repo
* `src_churn`: Number of src code lines changed by the pull request
* `test_churn`: Number of test lines changed by the pull request
* `commits_on_files_touched`: Number of commits on the files touch by the
pull request during the last month
* `test_lines_per_kloc`: Number of test (executable) lines per 1000 executable lines
* `test_cases_per_kloc`: Number of tests per 1000 executable lines
* `asserts_per_kloc`: Number of assert statements per 1000 executable lines
* `watchers`: Number of watchers (stars) to the repo at the time the pull
request was done.
* `requester`: The developer that performed the pull request
* `prev_pullreqs`: Number of pull requests by developer up to the specific pull request
* `requester_succ_rate`: % of merged vs unmerged pull requests for developer
* `followers`: Number of followers to the pull requester at the time the pull request was done
* `intra_branch`: Whether the pull request is among branches of the same
repository
* `main_team_member`: Boolean, true if the pull requester is part of the
project's main team at the time the pull request was opened.

The following features have been disabled from output: `num_commit_comments`,`num_issue_comments`, `files_added`, `files_deleted`, `files_modified`,
`src_files`, `doc_files`, `other_files`, `commits_last_month`, `main_team_commits_last_month`. In addition, the following features are 
not used in further analysis even if they are part of the data files:
`test_cases_per_kloc`,`asserts_per_kloc`, `watchers`, `followers`, `requester`

Lines reported are always executable lines of code (comments and whitespace have been stripped out). To count testing related data, the script exploits the fact that Java, Ruby and Python projects are organized using the Maven, Gem and Pythonic project conventions respectively. Test cases are recognized as follows:

* Java: Files in directories under a `/test/` branch of the file tree are
considered test files. JUnit 4 test cases are recognized using the `@Test`
tag. For JUnit3, methods starting with `test` are considered as test methods.
Asserts are counted by "grepping" through the source code lines for `assert*`
statements.

* Ruby: Files under the `/test/` and `/spec/` directories are considered
test files. Test cases are recognized by "grepping" for `test*` (RUnit),
`should .* do` (Shoulda) and `it .* do` (RSpec) in the source file lines.

* Python: http://pytest.org/latest/goodpractises.html#conventions-for-python-test-discovery

* Scala: Same as Java with the addition of specs2 matchers

####Processing data with R

The statistical analysis is done with R. Generally, it suffices to
do 

```bash
  cd pullreqs
  R --no-save < R/packages.R # install required packages
  Rscript R/one_of_the_scripts.R --help
```

The following scripts can be run with the procedure described above:

* [R/dataset-stats.R](https://github.com/gousiosg/pullreqs/blob/master/R/dataset-stats.R) Various statistics and plots that require access to the GHTorrent MySQL database. Use command line arguments to configure the MySQL connection.

* [R/pullreq-stats.R](https://github.com/gousiosg/pullreqs/blob/master/R/pullreq-stats.R) Pull request descriptive statistics (analysis of the data files).

* [R/run-merge-decision-classifiers.R](https://github.com/gousiosg/pullreqs/blob/master/R/run-merge-decision-classifiers.R): Cross validation runs for the pull request merge decision classifiers.

* [R/run-mergetime-classifiers.R](https://github.com/gousiosg/pullreqs/blob/master/R/run-mergetime-classifiers.R): Cross validation runs for the 
pull request merge time classifiers.

* [R/var-importance.R](https://github.com/gousiosg/pullreqs/blob/master/R/var-importance.R) Generate the variable importance plots for choosing important features


####Citation information
If you find this work interesting and want to use it in your work, please cite it as follows:

```
@inproceedings{GZ14,
  author = {Gousios, Georgios and Zaidman, Andy},
  title = {A Dataset for Pull-based Development Research},
  booktitle = {Proceedings of the 11th Working Conference on Mining Software Repositories},
  series = {MSR 2014},
  year = {2014},
  isbn = {978-1-4503-2863-0},
  location = {Hyderabad, India},
  pages = {368--371},
  numpages = {4},
  doi = {10.1145/2597073.2597122},
  acmid = {2597122},
  publisher = {ACM},
  address = {New York, NY, USA},
  keywords = {distributed software development, empirical software engineering, pull request, pull-based development},
}
```
