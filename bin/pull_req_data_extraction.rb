#!/usr/bin/env ruby
#
# (c) 2012 -- 2014 Georgios Gousios <gousiosg@gmail.com>
#
# BSD licensed, see LICENSE in top level dir
#


require 'rubygems'
require 'bundler'
require 'ghtorrent'
require 'time'
require 'linguist'
require 'grit'
require 'thread'
require 'parallel'

require 'java'
require 'ruby'
require 'scala'
require 'c'
require 'javascript'
require 'python'

class PullReqDataExtraction < GHTorrent::Command

  include GHTorrent::Persister
  include GHTorrent::Settings
  include Grit

  def prepare_options(options)
    options.banner <<-BANNER
Extract data for pull requests for a given repository

#{command_name} owner repo lang

    BANNER
  end

  def validate
    super
    Trollop::die 'Three arguments required' unless !args[2].nil?
  end

  def ght
    Thread.current[:ght] ||= GHTorrent::Mirror.new(settings)
    Thread.current[:ght]
  end

  def logger
    ght.logger
  end

  def db
    Thread.current[:sql_db] ||= ght.get_db
    Thread.current[:sql_db]
  end

  def mongo
    Thread.current[:mongo_db] ||= connect(:mongo, settings)
    Thread.current[:mongo_db]
  end

  def repo
    Thread.current[:repo] ||= clone(ARGV[0], ARGV[1])
    Thread.current[:repo]
  end

  def threads
    @threads ||= 1
    @threads
  end

  # Read a source file from the repo and strip its comments
  # The argument f is the result of Grit.lstree
  # Memoizes result per f
  def semaphore
    @semaphore ||= Mutex.new
    @semaphore
  end
  def stripped(f)
    @stripped ||= Hash.new
    unless @stripped.has_key? f
      semaphore.synchronize do
        unless @stripped.has_key? f
          @stripped[f] = strip_comments(repo.blob(f[:sha]).data)
        end
      end
    end
    @stripped[f]
  end

  # Main command code
  def go
    interrupted = false

    trap("INT") {
      STDERR.puts "pull_req_data_extraction(#{Process.pid}): Received SIGINT, exiting"
      interrupted = true
    }

    # Init the semaphore
    semaphore

    user_entry = ght.transaction{ght.ensure_user(ARGV[0], false, false)}

    if user_entry.nil?
      Trollop::die "Cannot find user #{ARGV[0]}"
    end

    repo_entry = ght.transaction{ght.ensure_repo(ARGV[0], ARGV[1], false, false, false)}

    if repo_entry.nil?
      Trollop::die "Cannot find repository #{ARGV[0]}/#{ARGV[1]}"
    end

    case ARGV[2]
      when /ruby/i then self.extend(RubyData)
      when /java/i then self.extend(JavaData)
      when /scala/i then self.extend(ScalaData)
      when /javascript/i then self.extend(JavascriptData)
      when /c/i then self.extend(CData)
      when /python/i then self.extend(PythonData)
    end

    # Update the repo
    clone(ARGV[0], ARGV[1], true)

    unless ARGV[3].nil?
      @threads = ARGV[3].to_i
    end

    format = [
        :pull_req_id, :project_name, :lang, :github_id,
        :created_at, :merged_at, :closed_at, :lifetime_minutes, :mergetime_minutes,
        :merged_using, :conflict, :forward_links,
        :team_size, :num_commits,
        :num_commit_comments,:num_issue_comments,
        :num_comments, :num_participants,
        :files_added, :files_deleted, :files_modified,
        :files_changed,
        :src_files, :doc_files, :other_files,
#        :commits_last_month, :main_team_commits_last_month,
        :perc_external_contribs,
        :sloc,:src_churn,:test_churn,:commits_on_files_touched,
        :test_lines_per_kloc,:test_cases_per_kloc,:asserts_per_kloc,
        :watchers,:requester,:prev_pullreqs,:requester_succ_rate,:followers,
        :intra_branch,:main_team_member
      ]

    # Print file header
    puts format.map{|x| x.to_s}.join(',')

    # Store all commits abbreviated SHA-1s for later comparisons

    @all_commits = (1..50).reduce(['master']) do |acc, x|
      acc + repo.commits(acc.last, 1000).map{|x| x.id_abbrev}
    end.flatten.sort.uniq[1..-1]

    # Get commits that close issues/pull requests
    # Index them by issue/pullreq id, as a sha might close multiple issues
    # see: https://help.github.com/articles/closing-issues-via-commit-messages
    q = <<-QUERY
    select c.sha
    from commits c, project_commits pc
    where pc.project_id = ?
    and pc.commit_id = c.id
    QUERY

    commits = mongo.get_underlying_connection['commits']
    fixre = /(?:fixe[sd]?|close[sd]?|resolve[sd]?)(?:[^\/]*?|and)#([0-9]+)/mi

    @closed_by_commit ={}
    @closed_by_commit = db.fetch(q, repo_entry[:id]).reduce({}) do |acc, x|
      sha = x[:sha]
      commits.find({:sha => sha},
                   {:fields => {'commit.message' => 1, '_id' => 0}}).each do |x|
        comment = x['commit']['message']
        comment.match(fixre) do |m|
          (1..(m.size - 1)).map do |y|
            acc[m[y].to_i] = sha
          end
        end
      end
      acc
    end

    # Process pull request list
    do_pr = Proc.new {|pr|
      begin
        r = process_pull_request(pr, ARGV[2].downcase)
        if interrupted
          return
        end
        r
      rescue Exception => e
        STDERR.puts "Error processing pull_request #{pr[:github_id]}: #{e.message}"
        STDERR.puts e.backtrace
        #raise e
      end
    }
    prs = pull_reqs(repo_entry)

    if threads > 1
      Parallel.map(prs, :in_threads => threads) do |pr|
        do_pr.call(pr)
      end.select{|x| !x.nil?}.sort{|a,b| b[:github_id]<=>a[:github_id]}.each{|x| puts x.values.join(',')}
    else
      prs.each do |pr|
        a = do_pr.call(pr);
        unless a.nil?
          puts a.values.join(',')
        end
      end
    end
  end

  # Get a list of pull requests for the processed project
  def pull_reqs(project)
    q = <<-QUERY
    select u.login as login, p.name as project_name, pr.id, pr.pullreq_id as github_id,
           a.created_at as created_at, b.created_at as closed_at,
			     (select created_at
            from pull_request_history prh1
            where prh1.pull_request_id = pr.id
            and prh1.action='merged' limit 1) as merged_at,
           timestampdiff(minute, a.created_at, b.created_at) as lifetime_minutes,
			timestampdiff(minute, a.created_at, (select created_at
                                           from pull_request_history prh1
                                           where prh1.pull_request_id = pr.id and prh1.action='merged' limit 1)
      ) as mergetime_minutes
    from pull_requests pr, projects p, users u,
         pull_request_history a, pull_request_history b
    where p.id = pr.base_repo_id
	    and a.pull_request_id = pr.id
      and a.pull_request_id = b.pull_request_id
      and a.action='opened' and b.action='closed'
	    and a.created_at < b.created_at
      and p.owner_id = u.id
      and p.id = ?
	  group by pr.id
    order by pr.pullreq_id desc;
    QUERY
    db.fetch(q, project[:id]).all
  end

  # Process a single pull request
  def process_pull_request(pr, lang)

    # Statistics across pull request commits
    stats = pr_stats(pr[:id])

    merged = ! pr[:merged_at].nil?
    git_merged = false
    merge_reason = :github

    if not merged
      git_merged, merge_reason = merged_with_git?(pr)
    end

    # Count number of src/comment lines
    src = src_lines(pr[:id].to_f)

    if src == 0 then raise Exception.new("Bad number of lines: #{0}") end

    commits_last_3_month = commits_last_x_months(pr[:id], false, 3)[0][:num_commits]
    prev_pull_reqs = prev_pull_requests(pr[:id],'opened')[0][:num_pull_reqs]

    # Create line for a pull request
    {
        :pull_req_id              => pr[:id],
        :project_name             => "#{pr[:login]}/#{pr[:project_name]}",
        :lang                     => lang,
        :github_id                => pr[:github_id],
        :created_at               => Time.at(pr[:created_at]).to_i,
        :merged_at                => merge_time(pr, merged, git_merged),
        :closed_at                => Time.at(pr[:closed_at]).to_i,
        :lifetime_minutes         => pr[:lifetime_minutes],
        :mergetime_minutes        => merge_time_minutes(pr, merged, git_merged),
        :merged_using             => merge_reason.to_s,
        :conflict                 => conflict?(pr[:login], pr[:project_name], pr[:github_id]),
        :forward_links            => forward_links?(pr[:login], pr[:project_name], pr[:github_id]),
        :team_size                => team_size_at_open(pr[:id], 3)[0][:teamsize],
        :num_commits              => num_commits(pr[:id])[0][:commit_count],
        :num_commit_comments     => num_comments(pr[:id])[0][:comment_count],
        :num_issue_comments      => num_issue_comments(pr[:id])[0][:issue_comment_count],
        :num_comments             => num_comments(pr[:id])[0][:comment_count] + num_issue_comments(pr[:id])[0][:issue_comment_count],
        :num_participants         => num_participants(pr[:id])[0][:participants],
        :files_added             => stats[:files_added],
        :files_deleted           => stats[:files_removed],
        :files_modified          => stats[:files_modified],
        :files_changed            => stats[:files_added] + stats[:files_modified] + stats[:files_removed],
        :src_files               => stats[:src_files],
        :doc_files               => stats[:doc_files],
        :other_files             => stats[:other_files],
        :perc_external_contribs   => ((commits_last_3_month - commits_last_x_months(pr[:id], true, 3)[0][:num_commits]) * 100) / commits_last_3_month,
        :sloc                     => src,
        :src_churn                => stats[:lines_added] + stats[:lines_deleted],
        :test_churn               => stats[:test_lines_added] + stats[:test_lines_deleted],
        :commits_on_files_touched => commits_on_files_touched(pr[:id], Time.at(Time.at(pr[:created_at]).to_i - 3600 * 24 * 90)),
        :test_lines_per_kloc      => (test_lines(pr[:id]).to_f / src.to_f) * 1000,
        :test_cases_per_kloc      => (num_test_cases(pr[:id]).to_f / src.to_f) * 1000,
        :asserts_per_kloc         => (num_assertions(pr[:id]).to_f / src.to_f) * 1000,
        :watchers                 => watchers(pr[:id])[0][:num_watchers],
        :requester                => requester(pr[:id])[0][:login],
        :prev_pullreqs            => prev_pull_reqs,
        :requester_succ_rate      => if prev_pull_reqs > 0 then prev_pull_requests(pr[:id], 'merged')[0][:num_pull_reqs].to_f / prev_pull_reqs.to_f else 0 end,
        :followers                => followers(pr[:id])[0][:num_followers],
        :intra_branch             => if intra_branch?(pr[:id])[0][:intra_branch] == 1 then true else false end,
        :main_team_member         => if main_team_member?(pr[:id])[0][:main_team_member] == 1 then true else false end
    }
  end

  def merge_time(pr, merged, git_merged)
    if merged
      Time.at(pr[:merged_at]).to_i
    elsif git_merged
      Time.at(pr[:closed_at]).to_i
    else
      ''
    end
  end

  def merge_time_minutes(pr, merged, git_merged)
    if merged
      Time.at(pr[:mergetime_minutes]).to_i
    elsif git_merged
      pr[:lifetime_minutes].to_i
    else
      ''
    end
  end

  # Checks whether a merge of the pull request occurred outside Github
  # This will only discover clean merges; rebases and force-pushes override
  # the commit history, so they are impossible to detect.
  def merged_with_git?(pr)

    #1. Commits from the pull request appear in the master branch
    q = <<-QUERY
	  select c.sha
    from pull_request_commits prc, commits c
	  where prc.commit_id = c.id
		  and prc.pull_request_id = ?
    QUERY
    db.fetch(q, pr[:id]).each do |x|
      unless @all_commits.select { |y| x[:sha].start_with? y }.empty?
        return [true, :commits_in_master]
      end
    end

    #2. The PR was closed by a commit (using the Fixes: convention).
    # Check whether the commit that closes the PR is in the project's
    # master branch
    unless @closed_by_commit[pr[:github_id]].nil?
      sha = @closed_by_commit[pr[:github_id]]
      if not @all_commits.select { |x| sha.start_with? x }.empty?
        return [true, :fixes_in_commit]
      end
    end

    comments = issue_comments(pr[:login], pr[:project_name], pr[:github_id])

    comments.reverse.take(3).map { |x| x['body'] }.uniq.each do |last|
      # 3. Last comment contains a commit number
      last.scan(/([0-9a-f]{6,40})/m).each do |x|
        # Commit is identified as merged
        if last.match(/merg(?:ing|ed)/i) or 
          last.match(/appl(?:ying|ied)/i) or
          last.match(/pull[?:ing|ed]/i) or
          last.match(/push[?:ing|ed]/i) or
          last.match(/integrat[?:ing|ed]/i) 
          return [true, :commit_sha_in_comments]
        else
          # Commit appears in master branch
          unless @all_commits.select { |y| x[0].start_with? y }.empty?
            return [true, :commit_sha_in_comments]
          end
        end
      end

      # 4. Merg[ing|ed] or appl[ing|ed] as last comment of pull request
      if last.match(/merg(?:ing|ed)/i) or 
        last.match(/appl(?:ying|ed)/i) or
        last.match(/pull[?:ing|ed]/i) or
        last.match(/push[?:ing|ed]/i) or
        last.match(/integrat[?:ing|ed]/i) 
        return [true, :merged_in_comments]
      end
    end

    [false, :unknown]
  end

  def conflict?(owner, repo, pr_id)
    issue_comments(owner, repo, pr_id).reduce(false) do |acc, x|
      acc || (not x['body'].match(/conflict/i).nil?)
    end
  end

  def forward_links?(owner, repo, pr_id)
    issue_comments(owner, repo, pr_id).reduce(false) do |acc, x|
      # Try to find pull_requests numbers referenced in each comment
      a = x['body'].scan(/\#([0-9]+)/m).reduce(false) do |acc1, m|
        if m[0].to_i > pr_id.to_i
          # See if it is a pull request (if not the number is an issue)
          q = <<-QUERY
            select *
            from pull_requests pr, projects p, users u
            where u.id = p.owner_id
              and pr.base_repo_id = p.id
              and u.login = ?
              and p.name = ?
              and pr.pullreq_id = ?
          QUERY
          acc1 || db.fetch(q, owner, repo, m[0]).all.size > 0
        else
          acc1
        end
      end
      acc || a
    end
  end

# Number of developers that have committed at least once in the interval
  # between the pull request open up to +interval_months+ back
  def team_size_at_open(pr_id, interval_months)
    q = <<-QUERY
    select count(distinct author_id) as teamsize
    from projects p, commits c, project_commits pc, pull_requests pr,
         pull_request_history prh
    where p.id = pc.project_id
      and pc.commit_id = c.id
      and p.id = pr.base_repo_id
      and prh.pull_request_id = pr.id
      and not exists (select * from pull_request_commits prc1 where prc1.commit_id = c.id)
      and prh.action = 'opened'
      and c.created_at < prh.created_at
      and c.created_at > DATE_SUB(prh.created_at, INTERVAL #{interval_months} MONTH)
      and pr.id=?;
    QUERY
    db.fetch(q, pr_id).all
  end

  # Number of commits in pull request
  def num_commits(pr_id)
    q = <<-QUERY
    select count(*) as commit_count
    from pull_requests pr, pull_request_commits prc
    where pr.id = prc.pull_request_id
      and pr.id=?
    group by prc.pull_request_id
    QUERY
    if_empty(db.fetch(q, pr_id).all, :commit_count)
  end

  # Number of src code review comments in pull request
  def num_comments(pr_id)
    q = <<-QUERY
    select count(*) as comment_count
    from pull_request_comments prc
    where prc.pull_request_id = ?
    and prc.created_at < (
      select max(created_at)
      from pull_request_history
      where action = 'closed' and pull_request_id = ?)
    QUERY
    if_empty(db.fetch(q, pr_id, pr_id).all, :comment_count)
  end

  # Number of pull request discussion comments
  def num_issue_comments(pr_id)
    q = <<-QUERY
    select count(*) as issue_comment_count
    from pull_requests pr, issue_comments ic, issues i
    where ic.issue_id=i.id
    and i.issue_id=pr.pullreq_id
    and pr.base_repo_id = i.repo_id
    and pr.id = ?
    and ic.created_at < (
      select max(created_at)
      from pull_request_history
      where action = 'closed' and pull_request_id = ?)
    QUERY
    if_empty(db.fetch(q, pr_id, pr_id).all, :issue_comment_count)
  end

  def num_participants(pr_id)
    q = <<-QUERY
    select count(distinct(user_id)) as participants from
      (select user_id
       from pull_request_comments
       where pull_request_id = ?
       union
       select user_id
       from issue_comments ic, issues i
       where i.id = ic.issue_id and i.pull_request_id = ?) as num_participants
    QUERY
    if_empty(db.fetch(q, pr_id, pr_id).all, :num_participants)
  end

  # Number of followers of the person that created the pull request
  # TODO: FIXME: Temporarily changed user_id->follower_id to fix issue in db
  def followers(pr_id)
    q = <<-QUERY
    select count(f.follower_id) as num_followers
    from pull_requests pr, followers f, pull_request_history prh
    where pr.user_id = f.user_id
      and prh.pull_request_id = pr.id
      and prh.action = 'opened'
      and f.created_at < prh.created_at
      and pr.id = ?
    QUERY
    if_empty(db.fetch(q, pr_id).all, :num_followers)
  end

  # Number of project watchers/stargazers at the time the pull request was made
  def watchers(pr_id)
    q = <<-QUERY
    select count(w.user_id) as num_watchers
    from watchers w, pull_requests pr, pull_request_history prh
    where prh.pull_request_id = pr.id
      and w.created_at < prh.created_at
      and w.repo_id = pr.base_repo_id
      and prh.action='opened'
      and pr.id = ?
    QUERY
    if_empty(db.fetch(q, pr_id).all, :num_watchers)
  end

  # Number of followers of the person that created the pull request
  def requester(pr_id)
    q = <<-QUERY
    select u.login as login
    from users u, pull_requests pr
    where pr.user_id = u.id
      and pr.id = ?
    QUERY
    if_empty(db.fetch(q, pr_id).all, :login)
  end

  # Number of pull
  def prev_pull_requests(pr_id, action)
    q = <<-QUERY
    select count(pullreq_id) as num_pull_reqs
    from pull_requests pr
    where pr.user_id = (select pr1.user_id from pull_requests pr1 where pr1.id = ?)
    and pr.base_repo_id = (select pr1.base_repo_id from pull_requests pr1 where pr1.id = ?)
    and exists (select * from pull_request_history prh where prh.action = ? and prh.pull_request_id = pr.id)
    and pr.pullreq_id < (select pr1.pullreq_id from pull_requests pr1 where pr1.id = ?)
    QUERY
    if_empty(db.fetch(q, pr_id, pr_id, action, pr_id).all, :num_pull_reqs)
  end

  # Check if the pull request is intra_branch
  def intra_branch?(pr_id)
    q = <<-QUERY
    select IF(base_repo_id = head_repo_id, true, false) as intra_branch
    from pull_requests where id = ?
    QUERY
    if_empty(db.fetch(q, pr_id).all, :intra_branch)
  end

  # Check if the requester is part of the project's main team
  def main_team_member?(pr_id)
    q = <<-QUERY
    select exists(select *
          from project_members
          where user_id = u.id and repo_id = pr.base_repo_id) as main_team_member
    from users u, pull_requests pr
    where pr.user_id = u.id
    and pr.id = ?
    QUERY
    if_empty(db.fetch(q, pr_id).all, :main_team_member)
  end

  # Various statistics for the pull request. Returned as Hash with the following
  # keys: :lines_added, :lines_deleted, :files_added, :files_removed,
  # :files_modified, :files_touched, :src_files, :doc_files, :other_files.
  def pr_stats(pr_id)

    raw_commits = commit_entries(pr_id)
    result = Hash.new(0)

    def file_count(commits, status)
      commits.map do |c|
        c['files'].reduce(Array.new) do |acc, y|
          if y['status'] == status then acc << y['filename'] else acc end
        end
      end.flatten.uniq.size
    end

    def files_touched(commits)
      commits.map do |c|
        c['files'].map do |y|
          y['filename']
        end
      end.flatten.uniq.size
    end

    def file_type(f)
      lang = Linguist::Language.detect(f, nil)
      if lang.nil? then :data else lang.type end
    end

    def file_type_count(commits, type)
      commits.map do |c|
        c['files'].reduce(Array.new) do |acc, y|
          if file_type(y['filename']) == type then acc << y['filename'] else acc end
        end
      end.flatten.uniq.size
    end

    def lines(commit, type, action)
      commit['files'].select do |x|
        next unless file_type(x['filename']) == :programming

        case type
          when :test
            true if test_file_filter.call(x['filename'])
          when :src
            true unless test_file_filter.call(x['filename'])
          else
            false
        end
      end.reduce(0) do |acc, y|
        diff_start = case action
                       when :added
                         "+"
                       when :deleted
                         "-"
                     end

        acc += unless y['patch'].nil?
                 y['patch'].lines.select{|x| x.start_with?(diff_start)}.size
               else
                 0
               end
        acc
      end
    end

    raw_commits.each{ |x|
      next if x.nil?
      result[:lines_added] += lines(x, :src, :added)
      result[:lines_deleted] += lines(x, :src, :deleted)
      result[:test_lines_added] += lines(x, :test, :added)
      result[:test_lines_deleted] += lines(x, :test, :deleted)
    }

    result[:files_added] += file_count(raw_commits, "added")
    result[:files_removed] += file_count(raw_commits, "removed")
    result[:files_modified] += file_count(raw_commits, "modified")
    result[:files_touched] += files_touched(raw_commits)

    result[:src_files] += file_type_count(raw_commits, :programming)
    result[:doc_files] += file_type_count(raw_commits, :markup)
    result[:other_files] += file_type_count(raw_commits, :data)

    result
  end

  def commits_on_files_touched(pr_id, oldest)
    pullreq = pull_req_entry(pr_id)
    commits = commit_entries(pr_id)
    commits_per_file = commits.flat_map { |c|
      c['files'].map { |f|
        [c['sha'], f['filename']]
      }
    }.group_by {|c|
      c[1]
    }
    commits_per_file.map { |k,v|
      commits_in_pr = commits_per_file[k].map{|x| x[0]}
      commits_in_pr.flat_map{|x|
        repo.log(x, k)
      }.find_all { |l|
        not commits_in_pr.include?(l.sha) and
        l.authored_date > oldest and
        l.authored_date < Time.parse(pullreq['created_at'])
      }.size
    }.flatten.reduce(0) { |acc, x| acc + x }  # Count the total number of commits
  end


  # Total number of commits on the project in the month before the pull request
  # was opened. The second parameter controls whether commits from other
  # pull requests should be accounted for
  def commits_last_x_months(pr_id, exclude_pull_req, months)
    q = <<-QUERY
    select count(c.id) as num_commits
    from projects p, commits c, project_commits pc, pull_requests pr,
         pull_request_history prh
    where p.id = pc.project_id
      and pc.commit_id = c.id
      and p.id = pr.base_repo_id
      and prh.pull_request_id = pr.id
      and prh.action = 'opened'
      and c.created_at < prh.created_at
      and c.created_at > DATE_SUB(prh.created_at, INTERVAL #{months} MONTH)
      and pr.id=?
    QUERY

    if exclude_pull_req
      q << ' and not exists (select * from pull_request_commits prc1 where prc1.commit_id = c.id)'
    end
    q << ';'

    if_empty(db.fetch(q, pr_id).all, :num_commits)
  end

  private

  def pull_req_entry(pr_id)
    q = <<-QUERY
    select u.login as user, p.name as name, pr.pullreq_id as pullreq_id
    from pull_requests pr, projects p, users u
    where pr.id = ?
    and pr.base_repo_id = p.id
    and u.id = p.owner_id
    QUERY
    pullreq = db.fetch(q, pr_id).all[0]

    entry = mongo.find(:pull_requests, {:owner => pullreq[:user],
                                        :repo => pullreq[:name],
                                        :number => pullreq[:pullreq_id]})[0]
    entry
  end

  # JSON objects for the commits included in the pull request
  def commit_entries(pr_id)
    q = <<-QUERY
    select c.sha as sha
    from pull_requests pr, pull_request_commits prc, commits c
    where pr.id = prc.pull_request_id
    and prc.commit_id = c.id
    and pr.id = ?
    QUERY
    commits = db.fetch(q, pr_id).all

    commits.reduce([]){ |acc, x|
      a = mongo.find(:commits, {:sha => x[:sha]})[0]
      acc << a unless a.nil?
      acc
    }.select{|c| c['parents'].size <= 1}
  end

  # List of files in a project checkout. Filter is an optional binary function
  # that takes a file entry and decides whether to include it in the result.
  def files_at_commit(pr_id, filter = lambda{true})
    q = <<-QUERY
    select c.sha
    from pull_requests p, commits c
    where c.id = p.base_commit_id
    and p.id = ?
    QUERY

    base_commit = db.fetch(q, pr_id).all[0][:sha]
    files = repo.lstree(base_commit, :recursive => true)

    files.select{|x| filter.call(x)}
  end

  # Returns all comments for the issue sorted by creation date ascending
  def issue_comments(owner, repo, pr_id)
    Thread.current[:issue_id] ||= pr_id

    if pr_id != Thread.current[:issue_id]
      Thread.current[:issue_id] = pr_id
      Thread.current[:issue_cmnt] = nil
    end

    Thread.current[:issue_cmnt] ||= Proc.new {
      issue_comments = mongo.get_underlying_connection['issue_comments']
      ic = issue_comments.find(
          {'owner' => owner, 'repo' => repo, 'issue_id' => pr_id.to_i},
          {:fields => {'body' => 1, 'created_at' => 1, '_id' => 0},
           :sort => {'created_at' => :asc}}
      ).map {|x| x}

    }.call
    Thread.current[:issue_cmnt]
  end

  def if_empty(result, field)
    if result.nil? or result.empty?
      [{field => 0}]
    else
      result
    end
  end

  def not_zero(result, field)
    if result[0][field].nil? or result[0][field] == 0
      raise Exception.new("Field #{field} cannot have value 0")
    else
      result
    end
  end

  def count_lines(files, include_filter = lambda{|x| true})
    files.map{ |f|
      stripped(f).lines.select{|x|
        not x.strip.empty?
      }.select{ |x|
        include_filter.call(x)
      }.size
    }.reduce(0){|acc,x| acc + x}
  end

  # Clone or update, if already cloned, a git repository
  def clone(user, repo, update = false)

    def spawn(cmd)
      proc = IO.popen(cmd, 'r')

      proc_out = Thread.new {
        while !proc.eof
          logger.debug "#{proc.gets}"
        end
      }

      proc_out.join
    end

    checkout_dir = File.join(config(:cache_dir), "repos", user, repo)

    begin
      repo = Grit::Repo.new(checkout_dir)
      if update
        spawn("cd #{checkout_dir} && git pull")
      end
      repo
    rescue
      spawn("git clone git://github.com/#{user}/#{repo}.git #{checkout_dir}")
      Grit::Repo.new(checkout_dir)
    end
  end

  # [buff] is an array of file lines, with empty lines stripped
  # [regexp] is a regexp or an array of regexps to match multiline comments
  def count_multiline_comments(buff, regexp)
    unless regexp.is_a?(Array) then regexp = [regexp] end

    regexp.reduce(0) do |acc, regexp|
      acc + buff.reduce(''){|acc,x| acc + x}.scan(regexp).map { |x|
        x.map{|y| y.lines.count}.reduce(0){|acc,y| acc + y}
      }.reduce(0){|acc, x| acc + x}
    end
  end

  # [buff] is an array of file lines, with empty lines stripped
  def count_single_line_comments(buff, comment_regexp)
    a = buff.select { |l|
      not l.match(comment_regexp).nil?
    }.size
    a
  end

  def src_files(pr_id)
    raise Exception.new("Unimplemented")
  end

  def src_lines(pr_id)
    raise Exception.new("Unimplemented")
  end

  def test_files(pr_id)
    raise Exception.new("Unimplemented")
  end

  def test_lines(pr_id)
    raise Exception.new("Unimplemented")
  end

  def num_test_cases(pr_id)
    raise Exception.new("Unimplemented")
  end

  def num_assertions(pr_id)
    raise Exception.new("Unimplemented")
  end

  # Return a function filename -> Boolean, that determines whether a
  # filename is a test file
  def test_file_filter
    raise Exception.new("Unimplemented")
  end

  def strip_comments(buff)
    raise Exception.new("Unimplemented")
  end

end

# Monkey patch grit to fix bug in commits containing signed patches
# see: http://alexdo.de/2013/03/25/how-i-fixed-grits-gpg-weakness/
class Grit::Commit
  class << self
    alias_method :original_list_from_string, :list_from_string

    def list_from_string(repo, text)
      text.gsub!(/gpgsig -----BEGIN PGP SIGNATURE-----[\n\r](.*[\n\r])*? -----END PGP SIGNATURE-----[\n\r]/, "")
      original_list_from_string(repo, text)
    end
  end
end

PullReqDataExtraction.run
#vim: set filetype=ruby expandtab tabstop=2 shiftwidth=2 autoindent smartindent:
