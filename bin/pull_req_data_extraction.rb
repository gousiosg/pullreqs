#!/usr/bin/env ruby
#
# (c) 2012 -- 2017 Georgios Gousios <gousiosg@gmail.com>
#
# BSD licensed, see LICENSE in top level dir
#

require 'time'
require 'linguist'
require 'thread'
require 'rugged'
require 'parallel'
require 'mongo'
require 'json'
require 'sequel'
require 'trollop'

require_relative 'java'
require_relative 'ruby'
require_relative 'scala'
require_relative 'c'
require_relative 'javascript'
require_relative 'python'

class PullReqDataExtraction

  REQ_LIMIT = 4990
  THREADS = 2

  attr_accessor :prs, :owner, :repo, :all_commits,
                :closed_by_commit, :close_reason, :token

  class << self
    def run(args = ARGV)
      attr_accessor :options, :args, :name, :config

      command = new()
      command.name = self.class.name
      command.args = args

      command.process_options
      command.validate

      command.config = YAML::load_file command.options[:config]

      command.go
    end
  end

  def process_options
    command = self
    @options = Trollop::options do
      banner <<-BANNER
Extract data for pull requests for a given repository

#{File.basename($0)} owner repo token

      BANNER
      opt :config, 'config.yaml file location', :short => 'c',
          :default => 'config.yaml'
    end
  end

  def validate
    if options[:config].nil?
      unless (file_exists?("config.yaml"))
        Trollop::die "No config file in default location (#{Dir.pwd}). You
                        need to specify the #{:config} parameter."
      end
    else
      Trollop::die "Cannot find file #{options[:config]}" \
          unless File.exists?(options[:config])
    end

    Trollop::die 'Two arguments required' unless !args[1].nil?
  end

  def db
    Thread.current[:sql_db] ||= Proc.new do
      Sequel.single_threaded = true
      Sequel.connect(self.config['sql']['url'], :encoding => 'utf8')
    end.call
    Thread.current[:sql_db]
  end

  def mongo
    Thread.current[:mongo_db] ||= Proc.new do
      uname  = self.config['mongo']['username']
      passwd = self.config['mongo']['password']
      host   = self.config['mongo']['host']
      port   = self.config['mongo']['port']
      db     = self.config['mongo']['db']

      constring = if uname.nil?
                    "mongodb://#{host}:#{port}/#{db}"
                  else
                    "mongodb://#{uname}:#{passwd}@#{host}:#{port}/#{db}"
                  end

      Mongo::Logger.logger.level = Logger::Severity::WARN
      Mongo::Client.new(constring)
    end.call
    Thread.current[:mongo_db]
  end

  def git
    Thread.current[:repo] ||= clone(ARGV[0], ARGV[1])
    Thread.current[:repo]
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
          @stripped[f] = strip_comments(git.read(f[:oid]).data)
        end
      end
    end
    @stripped[f]
  end

  def log(msg, level = 0)
    semaphore.synchronize do
      (0..level).each { STDERR.write ' ' }
      STDERR.puts msg
    end
  end

  # Main command code
  def go
    interrupted = false

    trap('INT') {
      log "#{File.basename($0)}(#{Process.pid}): Received SIGINT, exiting"
      interrupted = true
    }

    self.owner = ARGV[0]
    self.repo = ARGV[1]
    self.token = ARGV[2]

    user_entry = db[:users].first(:login => owner)

    if user_entry.nil?
      Trollop::die "Cannot find user #{owner}"
    end

    #repo_entry = db.from(:projects, :users).\
    #              where(:users__id => :projects__owner_id).\
    #              where(:users__login => owner).\
    #              where(:projects__name => repo).\
    #              select(:projects__id, :projects__language).\
    #              first
    repo_entry = db["SELECT projects.id, projects.language from projects, users WHERE (users.id = projects.owner_id) and (users.login = '#{owner}') and (projects.name = '#{repo}') LIMIT 1;"].first

    if repo_entry.nil?
      Trollop::die "Cannot find repository #{owner}/#{repo}"
    end

    language = repo_entry[:language]

    case language
      when /ruby/i then self.extend(RubyData)
      when /javascript/i then self.extend(JavascriptData)
      when /java/i then self.extend(JavaData)
      when /scala/i then self.extend(ScalaData)
      when /c/i then self.extend(CData)
      when /python/i then self.extend(PythonData)
      when /go/i then self.extend(GoData)
    end

    # Update the repo
    clone(ARGV[0], ARGV[1], true)

    walker = Rugged::Walker.new(git)
    walker.sorting(Rugged::SORT_DATE)
    walker.push(git.head.target)
    self.all_commits = walker.map do |commit|
      commit.oid[0..10]
    end
    log "#{all_commits.size} commits to process"

    # Get commits that close issues/pull requests
    # Index them by issue/pullreq id, as a sha might close multiple issues
    # see: https://help.github.com/articles/closing-issues-via-commit-messages
    q = <<-QUERY
    select c.sha
    from commits c, project_commits pc
    where pc.project_id = ?
    and pc.commit_id = c.id
    QUERY

    fixre = /(?:fixe[sd]?|close[sd]?|resolve[sd]?)(?:[^\/]*?|and)#([0-9]+)/mi

    log 'Calculating PRs closed by commits'
    commits_in_prs = db.fetch(q, repo_entry[:id]).all
    self.closed_by_commit =
        Parallel.map(commits_in_prs, :in_threads => THREADS) do |x|
          sha = x[:sha]
          result = {}
          mongo['commits'].find({:sha => sha},
                                {:fields => {'commit.message' => 1, '_id' => 0}}).map do |x|
            comment = x['commit']['message']

            comment.match(fixre) do |m|
              (1..(m.size - 1)).map do |y|
                result[m[y].to_i] = sha
              end
            end
          end
          result
        end.select { |x| !x.empty? }.reduce({}) { |acc, x| acc.merge(x) }
    log "#{closed_by_commit.size} PRs closed by commits"

    self.prs = pull_reqs(repo_entry)

    log "Calculating PR close reasons"
    self.close_reason = prs.reduce({}) do |acc, pr|
      mw = merged_with(pr)
      log "PR #{pr[:github_id]}, #{mw}"

      acc[pr[:github_id]] = mw
      acc
    end
    log "Close reasons: #{close_reason.group_by { |_, v| v }.reduce({}) { |acc, x| acc.merge({x[0] => x[1].size}) }}"

    # Process pull request list
    do_pr = Proc.new do |pr|
      begin
        r = process_pull_request(pr, language)
        log r
        r
      rescue StandardError => e
        log "Error processing pull_request #{pr[:github_id]}: #{e.message}"
        log e.backtrace
        #raise e
      end
    end

    results = Parallel.map(prs, :in_threads => THREADS) do |pr|
      if interrupted
        raise Parallel::Kill
      end
      do_pr.call(pr)
    end

    unless results.nil?
      puts results.select { |x| !x.nil? }.first.keys.map{|x| x.to_s}.join(',')
      results.select { |x| !x.nil? }.sort{|a,b| b[:github_id]<=>a[:github_id]}.each{|x| puts x.values.join(',')}
    end
  end

  # Get a list of pull requests for the processed project
  def pull_reqs(project, github_id = -1)
    q = <<-QUERY
    select u.login as login, p.name as project_name, pr.id, pr.pullreq_id as github_id,
           a.created_at as created_at, b.created_at as closed_at, c.sha as base_commit,
           c1.sha as head_commit,
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
         pull_request_history a, pull_request_history b, commits c, commits c1
    where p.id = pr.base_repo_id
	    and a.pull_request_id = pr.id
      and a.pull_request_id = b.pull_request_id
      and a.action='opened' and b.action='closed'
	    and a.created_at < b.created_at
      and p.owner_id = u.id
      and c1.id = pr.head_commit_id
      and c.id = pr.base_commit_id
      and p.id = ?
    QUERY

    if github_id != -1
      q += " and pr.pullreq_id = #{github_id} "
    end
    q += 'group by pr.id order by pr.pullreq_id desc;'

    db.fetch(q, project[:id]).all
  end

  # Process a single pull request
  def process_pull_request(pr, lang)

    # Statistics across pull request commits
    stats = pr_stats(pr)
    stats_open = pr_stats(pr, true)

    # Test diff stats
    pr_commits = commit_entries(pr[:id], true).sort{|a,b| a['commit']['author']['date'] <=> b['commit']['author']['date']}
    test_diff_open = test_diff_stats(pr[:base_commit], pr_commits.last[:sha])

    pr_commits = commit_entries(pr[:id], false).sort{|a,b| a['commit']['author']['date'] <=> b['commit']['author']['date']}
    test_diff = test_diff_stats(pr[:base_commit], pr_commits.last[:sha])

    # Count number of src/comment lines
    src = src_lines(pr[:base_commit])

    if src == 0 then raise StandardError.new("Bad src lines: 0, pr: #{pr[:github_id]}, id: #{pr[:id]}") end

    months_back = 3
    commits_incl_prs = commits_last_x_months(pr, false, months_back)
    commits_incl_prs = 1 if commits_incl_prs == 0 # To avoid divsions by zero below

    prev_pull_reqs = prev_pull_requests(pr,'opened')

    # Create line for a pull request
    {
        # General stuff
        :pull_req_id              => pr[:id],
        :project_name             => "#{pr[:login]}/#{pr[:project_name]}",
        :lang                     => lang,
        :github_id                => pr[:github_id],

        # PR characteristics
        :created_at               => Time.at(pr[:created_at]).to_i,
        :merged_at                => merge_ts(pr),
        :closed_at                => Time.at(pr[:closed_at]).to_i,
        :lifetime_minutes         => pr[:lifetime_minutes],
        :mergetime_minutes        => merge_time_minutes(pr),
        :merged_using             => close_reason[pr[:github_id]],
        :conflict                 => conflict?(pr),
        :forward_links            => forward_links?(pr),
        :intra_branch             => if intra_branch?(pr) == 1 then true else false end,
        :description_length       => description_length(pr),
        :num_commits              => num_commits(pr),
        :num_commits_open         => num_commits_at_open(pr),
        :num_pr_comments          => num_pr_comments(pr),
        :num_issue_comments       => num_issue_comments(pr),
        :num_commit_comments      => num_commit_comments(pr),
        :num_comments             => num_pr_comments(pr) + num_issue_comments(pr) + num_commit_comments(pr),
        :num_commit_comments_open => num_commit_comments(pr, true),
        :num_participants         => num_participants(pr),
        :files_added_open         => stats_open[:files_added],
        :files_deleted_open       => stats_open[:files_removed],
        :files_modified_open      => stats_open[:files_modified],
        :files_changed_open       => stats_open[:files_added] + stats[:files_modified] + stats[:files_removed],
        :src_files_open           => stats_open[:src_files],
        :doc_files_open           => stats_open[:doc_files],
        :other_files_open         => stats_open[:other_files],
        :files_added              => stats[:files_added],
        :files_deleted            => stats[:files_removed],
        :files_modified           => stats[:files_modified],
        :files_changed            => stats[:files_added] + stats[:files_modified] + stats[:files_removed],
        :src_files                => stats[:src_files],
        :doc_files                => stats[:doc_files],
        :other_files              => stats[:other_files],
        :src_churn_open           => stats_open[:lines_added] + stats_open[:lines_deleted],
        :test_churn_open          => stats_open[:test_lines_added] + stats_open[:test_lines_deleted],
        :tests_added_open         => test_diff_open[:tests_added],
        :tests_deleted_open       => test_diff_open[:tests_deleted],
        :tests_added              => test_diff[:tests_added],
        :tests_deleted            => test_diff[:tests_deleted],
        :src_churn                => stats[:lines_added] + stats[:lines_deleted],
        :test_churn               => stats[:test_lines_added] + stats[:test_lines_deleted],
        :new_entropy              => new_entropy(pr),
        :entropy_diff             => (new_entropy(pr) / project_entropy(pr)) * 100,
        :commits_on_files_touched => commits_on_files_touched(pr, months_back),
        :commits_to_hottest_file  => commits_to_hottest_file(pr, months_back),
        :hotness                  => hotness(pr, months_back),
        :at_mentions_description  => at_mentions_description(pr),
        :at_mentions_comments     => at_mentions_comments(pr),

        # Project characteristics
        :perc_external_contribs   => commits_last_x_months(pr, true, months_back).to_f / commits_incl_prs.to_f,
        :sloc                     => src,
        :test_lines               => test_lines(pr[:base_commit]),
        :test_cases               => num_test_cases(pr[:base_commit]),
        :asserts                  => num_assertions(pr[:base_commit]),
        :stars                    => stars(pr),
        :team_size                => team_size(pr, months_back),
        :workload                 => workload(pr),
        :ci                       => ci(pr),

        # Contributor characteristics
        :requester                => requester(pr),
        :closer                   => closer(pr),
        :merger                   => merger(pr),
        :prev_pullreqs            => prev_pull_reqs,
        :requester_succ_rate      => if prev_pull_reqs > 0 then prev_pull_requests(pr, 'merged').to_f / prev_pull_reqs.to_f else 0 end,
        :followers                => followers(pr),
        :main_team_member         => main_team_member?(pr, months_back),
        :social_connection        => social_connection?(pr),

        # Project/contributor interaction characteristics
        :prior_interaction_issue_events    => prior_interaction_issue_events(pr, months_back),
        :prior_interaction_issue_comments  => prior_interaction_issue_comments(pr, months_back),
        :prior_interaction_pr_events       => prior_interaction_pr_events(pr, months_back),
        :prior_interaction_pr_comments     => prior_interaction_pr_comments(pr, months_back),
        :prior_interaction_commits         => prior_interaction_commits(pr, months_back),
        :prior_interaction_commit_comments => prior_interaction_commit_comments(pr, months_back),
        :first_response                    => first_response(pr)
    }
  end

  def merge_ts(pr)

    if not pr[:merged_at].nil?
      Time.at(pr[:merged_at]).to_i
    elsif close_reason[pr[:github_id]] == :commits_in_master
      Time.at(pr[:closed_at]).to_i
    else
      nil
    end
  end

  def merge_time_minutes(pr)
    if not pr[:merged_at].nil?
      Time.at(pr[:mergetime_minutes]).to_i
    elsif close_reason[pr[:github_id]] == :commits_in_master
      pr[:lifetime_minutes].to_i
    else
      nil
    end
  end

  # Checks how a merge occured
  def merged_with(pr)
    #0. Merged with Github?
    q = <<-QUERY
	  select prh.id as merge_id
    from pull_request_history prh
	  where prh.action = 'merged'
      and prh.pull_request_id = ?
    QUERY
    r = db.fetch(q, pr[:id]).first
    unless r.nil?
      return :merge_button
    end

    #1. Commits from the pull request appear in the project's main branch
    q = <<-QUERY
	  select c.sha
    from pull_request_commits prc, commits c
	  where prc.commit_id = c.id
      and prc.pull_request_id = ?
    QUERY
    db.fetch(q, pr[:id]).each do |x|
      unless all_commits.select { |y| x[:sha].start_with? y }.empty?
        return :commits_in_master
      end
    end

    #2. The PR was closed by a commit (using the Fixes: convention).
    # Check whether the commit that closes the PR is in the project's
    # master branch
    sha = closed_by_commit[pr[:github_id]]
    unless sha.nil?
      unless all_commits.include? sha
        return :fixes_in_commit
      end
    end

    comments = mongo['issue_comments'].find(
        {'owner' => owner, 'repo' => repo, 'issue_id' => pr[:github_id].to_i},
        {:projection => {'body' => 1, 'created_at' => 1, '_id' => 0},
         :sort => {'created_at' => 1}}
    ).map { |x| x }

    comments.reverse.take(3).map { |x| x['body'] }.uniq.each do |last|
      # 3. Last comment contains a commit number
      last.scan(/([0-9a-f]{6,40})/m).each do |x|
        # Commit is identified as merged
        if last.match(/merg(?:ing|ed)/i) or
            last.match(/appl(?:ying|ied)/i) or
            last.match(/pull[?:ing|ed]/i) or
            last.match(/push[?:ing|ed]/i) or
            last.match(/integrat[?:ing|ed]/i)
          return :commit_sha_in_comments
        else
          # Commit appears in master branch
          unless all_commits.select { |y| x[0].start_with? y }.empty?
            return :commit_sha_in_comments
          end
        end
      end

      # 4. Merg[ing|ed] or appl[ing|ed] as last comment of pull request
      if last.match(/merg(?:ing|ed)/i) or
          last.match(/appl(?:ying|ed)/i) or
          last.match(/pull[?:ing|ed]/i) or
          last.match(/push[?:ing|ed]/i) or
          last.match(/integrat[?:ing|ed]/i)
        return :merged_in_comments
      end
    end

    :unknown
  end

  def conflict?(pr)
    issue_comments(pr[:owner], pr[:project_name], pr[:id]).reduce(false) do |acc, x|
      acc || (not x['body'].match(/conflict/i).nil?)
    end
  end

  def forward_links?(pr)
    owner = pr[:login]
    repo = pr[:project_name]
    pr_id = pr[:github_id]
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

  def num_commits_at_open(pr)
    q = <<-QUERY
    select count(*) as commit_count
    from pull_requests pr, pull_request_commits prc, commits c, pull_request_history prh
    where pr.id = prc.pull_request_id
      and pr.id=?
      and prc.commit_id = c.id
      and prh.action = 'opened'
      and prh.pull_request_id = pr.id
      and c.created_at <= prh.created_at
    group by prc.pull_request_id
    QUERY
    begin
      db.fetch(q, pr[:id]).first[:commit_count]
    rescue
      0
    end
  end

  # Number of commits in pull request
  def num_commits(pr)
    q = <<-QUERY
    select count(*) as commit_count
    from pull_requests pr, pull_request_commits prc
    where pr.id = prc.pull_request_id
      and pr.id=?
    group by prc.pull_request_id
    QUERY
    begin
      db.fetch(q, pr[:id]).first[:commit_count]
    rescue
      0
    end
  end

  # Number of pull request code review comments in pull request
  def num_pr_comments(pr)
    q = <<-QUERY
    select count(*) as comment_count
    from pull_request_comments prc
    where prc.pull_request_id = ?
    and prc.created_at < (
      select max(created_at)
      from pull_request_history
      where action = 'closed' and pull_request_id = ?)
    QUERY
    db.fetch(q, pr[:id], pr[:id]).first[:comment_count]
  end

  # Number of pull request discussion comments
  def num_issue_comments(pr)
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
    db.fetch(q, pr[:id], pr[:id]).first[:issue_comment_count]
  end

  # Number of commit comments on commits composing the pull request
  def num_commit_comments(pr, at_open = false)
    if at_open
      q = <<-QUERY
      select count(*) as commit_comment_count
      from pull_request_commits prc, commit_comments cc,
           pull_request_history prh
      where prc.commit_id = cc.commit_id
        and prh.action = 'opened'
        and cc.created_at <= prh.created_at
        and prh.pull_request_id = prc.pull_request_id
        and prc.pull_request_id = ?
      QUERY
    else
      q = <<-QUERY
      select count(*) as commit_comment_count
      from pull_request_commits prc, commit_comments cc
      where prc.commit_id = cc.commit_id
        and prc.pull_request_id = ?
      QUERY
    end
    db.fetch(q, pr[:id]).first[:commit_comment_count]
  end

  def num_participants(pr)
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
    db.fetch(q, pr[:id], pr[:id]).first[:participants]
  end

  # Number of followers of the person that created the pull request
  def followers(pr)
    q = <<-QUERY
    select count(f.follower_id) as num_followers
    from pull_requests pr, followers f, pull_request_history prh
    where prh.actor_id = f.user_id
      and prh.pull_request_id = pr.id
      and prh.action = 'opened'
      and f.created_at < prh.created_at
      and pr.id = ?
    QUERY
    db.fetch(q, pr[:id]).first[:num_followers]
  end

  # Number of project watchers/stargazers at the time the pull request was made
  def stars(pr)
    q = <<-QUERY
    select count(w.user_id) as num_watchers
    from watchers w, pull_requests pr, pull_request_history prh
    where prh.pull_request_id = pr.id
      and w.created_at < prh.created_at
      and w.repo_id = pr.base_repo_id
      and prh.action='opened'
      and pr.id = ?
    QUERY
    db.fetch(q, pr[:id]).first[:num_watchers]
  end

  # Person that first closed the pull request
  def closer(pr)
    q = <<-QUERY
    select u.login as login
    from pull_request_history prh, users u
    where prh.pull_request_id = ?
      and prh.actor_id = u.id
      and prh.action = 'closed'
    QUERY
    closer = db.fetch(q, pr[:id]).first

    if closer.nil?
      q = <<-QUERY
      select u.login as login
      from issues i, issue_events ie, users u
      where i.pull_request_id = ?
        and ie.issue_id = i.id
        and (ie.action = 'closed' or ie.action = 'merged')
        and u.id = ie.actor_id
      QUERY
      closer = db.fetch(q, pr[:id]).first
    end

    unless closer.nil?
      closer[:login]
    else
      nil
    end
  end

  # Person that first merged the pull request
  def merger(pr)
    q = <<-QUERY
    select u.login as login
    from issues i, issue_events ie, users u
    where i.pull_request_id = ?
      and ie.issue_id = i.id
      and ie.action = 'merged'
      and u.id = ie.actor_id
    QUERY
    merger = db.fetch(q, pr[:id]).first

    if merger.nil?
      # If the PR was merged, then it is safe to assume that the
      # closer is also the merger
      if not close_reason[pr[:github_id]].nil? and close_reason[pr[:github_id]] != :unknown
        closer(pr)
      else
        nil
      end
    else
      merger[:login]
    end
  end

  # Number of followers of the person that created the pull request
  def requester(pr)
    q = <<-QUERY
    select u.login as login
    from users u, pull_request_history prh
    where prh.actor_id = u.id
      and action = 'opened'
      and prh.pull_request_id = ?
    QUERY
    db.fetch(q, pr[:id]).first[:login]
  end

  # Number of previous pull requests for the pull requester
  def prev_pull_requests(pr, action)

    if action == 'merged'
      q = <<-QUERY
      select pr.pullreq_id, prh.pull_request_id as num_pull_reqs
      from pull_request_history prh, pull_requests pr
      where prh.action = 'opened'
        and prh.created_at < (select min(created_at) from pull_request_history prh1 where prh1.pull_request_id = ? and prh1.action = 'opened')
        and prh.actor_id = (select min(actor_id) from pull_request_history prh1 where prh1.pull_request_id = ? and prh1.action = 'opened')
        and prh.pull_request_id = pr.id
        and pr.base_repo_id = (select pr1.base_repo_id from pull_requests pr1 where pr1.id = ?);
      QUERY

      pull_reqs = db.fetch(q, pr[:id], pr[:id], pr[:id]).all
      pull_reqs.reduce(0) do |acc, pull_req|
        if not close_reason[pull_req[:pullreq_id]].nil? and close_reason[pull_req[:pullreq_id]][1] != :unknown
          acc += 1
        end
        acc
      end
    else
      q = <<-QUERY
      select pr.pullreq_id, prh.pull_request_id as num_pull_reqs
      from pull_request_history prh, pull_requests pr
      where prh.action = ?
        and prh.created_at < (select min(created_at) from pull_request_history prh1 where prh1.pull_request_id = ?)
        and prh.actor_id = (select min(actor_id) from pull_request_history prh1 where prh1.pull_request_id = ? and action = ?)
        and prh.pull_request_id = pr.id
        and pr.base_repo_id = (select pr1.base_repo_id from pull_requests pr1 where pr1.id = ?);
      QUERY
      db.fetch(q, action, pr[:id], pr[:id], action, pr[:id]).all.size
    end
  end

  # Do the contributor and the person that closed the PR follow
  # each other?
  # Defined in: Tsay, Jason, Laura Dabbish, and James Herbsleb.
  # "Influence of social and technical factors for evaluating contribution in GitHub."
  # Proceedings of the ICSE 2014
  def social_connection?(pr)
    q = <<-QUERY
    select *
    from followers
    where user_id = (
      select min(prh.actor_id)
      from pull_request_history prh
      where prh.pull_request_id = ?
        and prh.action = 'closed'
        )
    and follower_id = (
      select min(prh.actor_id)
      from pull_request_history prh
      where prh.pull_request_id = ?
        and prh.action = 'opened'
        )
    and created_at < (
      select min(created_at)
        from pull_request_history
        where pull_request_id = ?
        and action = 'opened'
    )
    QUERY
    db.fetch(q, pr[:id], pr[:id], pr[:id]).all.size > 0
  end

  # People that merged (not necessarily through pull requests) up to months_back
  # from the time the built PR was created.
  def merger_team(pr, months_back)
    recently_merged = prs.find_all do |b|
      close_reason[b[:github_id]][1] != :unknown and
          b[:created_at].to_i > (pr[:created_at].to_i - months_back * 30 * 24 * 3600)
    end.map do |b|
      b[:github_id]
    end

    q = <<-QUERY
    select u1.login as merger
    from users u, projects p, pull_requests pr, pull_request_history prh, users u1
    where prh.action = 'closed'
      and prh.actor_id = u1.id
      and prh.pull_request_id = pr.id
      and pr.base_repo_id = p.id
      and p.owner_id = u.id
      and u.login = ?
      and p.name = ?
      and pr.pullreq_id = ?
    QUERY

    recently_merged.map do |pr_num|
      a = db.fetch(q, pr[:login], pr[:project_name], pr_num).first
      if not a.nil? then a[:merger] else nil end
    end.select {|x| not x.nil?}.uniq

  end

  # Number of integrators active during x months prior to pull request
  # creation.
  def team_size(pr, months_back)
    (committer_team(pr, months_back) + merger_team(pr, months_back)).uniq.size
  end

  # The number of events before a particular pull request that the user has
  # participated in for this project.
  # The following features originate in:
  # Yu, Y., Wang, H., Filkov, V., Devanbu, P., & Vasilescu, B.
  # Wait For It: Determinants of Pull Request Evaluation Latency on GitHub.
  # MSR 2015
  def prior_interaction_issue_events(pr, months_back)
    q = <<-QUERY
      select count(distinct(i.id)) as num_issue_events
      from issue_events ie, pull_request_history prh, pull_requests pr, issues i
      where ie.actor_id = prh.actor_id
        and i.repo_id = pr.base_repo_id
        and i.id = ie.issue_id
        and prh.pull_request_id = pr.id
        and prh.action = 'opened'
        and ie.created_at > DATE_SUB(prh.created_at, INTERVAL #{months_back} MONTH)
        and ie.created_at < prh.created_at
        and prh.pull_request_id = ?
    QUERY
    db.fetch(q, pr[:id]).first[:num_issue_events]
  end

  def prior_interaction_issue_comments(pr, months_back)
    q = <<-QUERY
    select count(distinct(ic.comment_id)) as issue_comment_count
    from pull_request_history prh, pull_requests pr, issues i, issue_comments ic
    where ic.user_id = prh.actor_id
      and i.repo_id = pr.base_repo_id
      and i.id = ic.issue_id
      and prh.pull_request_id = pr.id
      and prh.action = 'opened'
      and ic.created_at > DATE_SUB(prh.created_at, INTERVAL #{months_back} MONTH)
      and ic.created_at < prh.created_at
      and prh.pull_request_id = ?;
    QUERY
    db.fetch(q, pr[:id]).first[:issue_comment_count]
  end

  def prior_interaction_pr_events(pr, months_back)
    q = <<-QUERY
    select count(distinct(prh1.id)) as count_pr
    from  pull_request_history prh1, pull_request_history prh, pull_requests pr1, pull_requests pr
    where prh1.actor_id = prh.actor_id
      and pr1.base_repo_id = pr.base_repo_id
      and pr1.id = prh1.pull_request_id
      and pr.id = prh.pull_request_id
      and prh.action = 'opened'
      and prh1.created_at > DATE_SUB(prh.created_at, INTERVAL #{months_back} MONTH)
      and prh1.created_at < prh.created_at
      and prh.pull_request_id = ?
    QUERY
    db.fetch(q, pr[:id]).first[:count_pr]
  end

  def prior_interaction_pr_comments(pr, months_back)
    q = <<-QUERY
    select count(prc.comment_id) as count_pr_comments
    from pull_request_history prh, pull_requests pr1, pull_requests pr, pull_request_comments prc
    where prh.actor_id = prc.user_id
      and pr1.base_repo_id = pr.base_repo_id
      and pr1.id = prh.pull_request_id
      and pr.id = prc.pull_request_id
      and prh.action = 'opened'
      and prc.created_at > DATE_SUB(prh.created_at, INTERVAL #{months_back} MONTH)
      and prc.created_at < prh.created_at
      and prh.pull_request_id = ?
    QUERY
    db.fetch(q, pr[:id]).first[:count_pr_comments]
  end

  def prior_interaction_commits(pr, months_back)
    q = <<-QUERY
    select count(distinct(c.id)) as count_commits
    from pull_request_history prh, pull_requests pr, commits c, project_commits pc
    where (c.author_id = prh.actor_id or c.committer_id = prh.actor_id)
      and pc.project_id = pr.base_repo_id
      and c.id = pc.commit_id
      and prh.pull_request_id = pr.id
      and prh.action = 'opened'
      and c.created_at > DATE_SUB(prh.created_at, INTERVAL #{months_back} MONTH)
      and c.created_at < prh.created_at
      and prh.pull_request_id = ?;
    QUERY
    db.fetch(q, pr[:id]).first[:count_commits]
  end

  def prior_interaction_commit_comments(pr, months_back)
    q = <<-QUERY
    select count(distinct(cc.id)) as count_commits
    from pull_request_history prh, pull_requests pr, commits c, project_commits pc, commit_comments cc
    where cc.commit_id = c.id
      and cc.user_id = prh.actor_id
      and pc.project_id = pr.base_repo_id
      and c.id = pc.commit_id
      and prh.pull_request_id = pr.id
      and prh.action = 'opened'
      and cc.created_at > DATE_SUB(prh.created_at, INTERVAL #{months_back} MONTH)
      and cc.created_at < prh.created_at
      and prh.pull_request_id = ?;

    QUERY
    db.fetch(q, pr[:id]).first[:count_commits]
  end

  # Median number of commits to files touched by the pull request relative to
  # all (including those coming from PRs) project commits during the last three months
  def hotness(pr, months_back)
    commits_per_file = commits_on_pr_files(pr, months_back).map{|x| x[1].size}.sort
    med = commits_per_file[commits_per_file.size/2]
    med = 0 if med.nil?
    all_commits = commits_last_x_months(pr, false, months_back)
    all_commits = 1 if all_commits == 0
    med / all_commits.to_f
  end

  # People that committed (not through pull requests) up to months_back
  # from the time the PR was created.
  def committer_team(pr, months_back)
    q = <<-QUERY
    select distinct(u.login) as committer
    from commits c, project_commits pc, pull_requests pr, users u, pull_request_history prh
    where pr.base_repo_id = pc.project_id
      and not exists (select * from pull_request_commits where commit_id = c.id)
      and pc.commit_id = c.id
      and pr.id = ?
      and u.id = c.committer_id
      and u.fake is false
      and prh.pull_request_id = pr.id
      and prh.action = 'opened'
      and c.created_at > DATE_SUB(prh.created_at, INTERVAL #{months_back} MONTH)
      and c.created_at < prh.created_at;
    QUERY
    db.fetch(q, pr[:id]).all.map{|x| x[:committer]}
  end

  # Time interval in minutes from pull request creation to first response
  # by reviewers
  def first_response(pr)
    q = <<-QUERY
      select min(created) as first_resp from (
        select min(prc.created_at) as created
        from pull_request_comments prc, users u
        where prc.pull_request_id = ?
          and u.id = prc.user_id
          and u.login not in ('travis-ci', 'cloudbees')
          and prc.created_at < (
            select max(created_at)
            from pull_request_history
            where action = 'closed' and pull_request_id = ?)
        union
        select min(ic.created_at) as created
        from issues i, issue_comments ic, users u
        where i.pull_request_id = ?
          and i.id = ic.issue_id
          and u.id = ic.user_id
          and u.login not in ('travis-ci', 'cloudbees')
          and ic.created_at < (
            select max(created_at)
            from pull_request_history
            where action = 'closed' and pull_request_id = ?)
      ) as a;
    QUERY
    resp = db.fetch(q, pr[:id], pr[:id], pr[:id], pr[:id]).first[:first_resp]
    unless resp.nil?
      (resp - pr[:created_at]).to_i / 60
    else
      -1
    end
  end

  # Number of commits to the hottest file between the time the PR was created
  # and `months_back`
  def commits_to_hottest_file(pr, months_back)
    a = commits_on_pr_files(pr, months_back).map{|x| x}.sort_by { |x| x[1].size}
    unless a.empty?
      a.last[1].size
    else
      0
    end
  end

  CIBADGES = {
      /https:\/\/.*.cloudbees.com\/buildStatus\/icon/    => :cloudbees,
      /https:\/\/circleci.com\/gh\/.*\.(png|svg)/        => :circleci,
      /https:\/\/travis-ci.org\/.*\.(svg|png)/           => :travis,
      /https:\/\/app.wercker.com\/status\/.*\/m/         => :wrecker,
      /https:\/\/api.shippable.com\/projects\/.*\/badge/ => :shippable,
      /https:\/\/codeship.com\/projects\/.*\/status/     => :codeship,
      /https:\/\/semaphoreapp.com\/vast/                 => :semaphoreapp,
      /https:\/\/snap-ci.com\/.*\/branch/                => :snapci
  }

  CICONFIGS = {
      /.travis.y[a]?ml/   => :travis,
      /circle.y[a]?ml/    => :circleci,
      /shippable.y[a]?ml/ => :shippable,
      /wercker.y[a]?ml/   => :wercker
  }

  def ci(pr)
    # Check whether a CI configuration file exists in the root directory
    root_files = files_at_commit(pr[:base_commit], lambda{|f| f[:path].count('/') == 1})
    root_files.each do |f|
      CICONFIGS.keys.each do |ci|
        return CICONFIGS[ci] unless f[:path].match(ci).nil?
      end
    end

    # Check whether a README file contains a CI badge
    readmes = root_files.find{|f| f[:path].match(/\/README/)}
    return :unknown if readmes.nil? or readmes.empty?
    return :unknown if readmes[0].nil?

    readme = git.read(readmes[0][:oid]).data
    CIBADGES.keys.each do |badge|
      if readme.match(badge)
        return CIBADGES[badge]
      end
    end

    return :unknown
  end

  # Total number of words in the pull request title and description
  def description_length(pr)
    pull_req = pull_req_entry(pr)
    title = unless pull_req['title'].nil? then pull_req['title'] else ' ' end
    body = unless pull_req['body'].nil? then pull_req['body'] else ' ' end
    (title + ' ' + body).gsub(/[\n\r]\s+/, ' ').split(/\s+/).size
  end

  # Total number of pull requests still open in each project at pull
  # request creation time.
  def workload(pr)
    q = <<-QUERY
    select count(distinct(prh.pull_request_id)) as num_open
    from pull_request_history prh, pull_requests pr, pull_request_history prh3
    where prh.created_at <  prh3.created_at
    and prh.action = 'opened'
    and pr.id = prh.pull_request_id
    and prh3.pull_request_id = ?
    and (exists (select * from pull_request_history prh1
                where prh1.action = 'closed'
          and prh1.pull_request_id = prh.pull_request_id
          and prh1.created_at > prh3.created_at)
      or not exists (select * from pull_request_history prh1
               where prh1.action = 'closed'
               and prh1.pull_request_id = prh.pull_request_id)
    )
    and pr.base_repo_id = (select pr3.base_repo_id from pull_requests pr3 where pr3.id = ?)
    QUERY
    db.fetch(q, pr[:id], pr[:id]).first[:num_open]
  end

  # Check if the pull request is intra_branch
  def intra_branch?(pr)
    q = <<-QUERY
    select IF(base_repo_id = head_repo_id, true, false) as intra_branch
    from pull_requests where id = ?
    QUERY
    db.fetch(q, pr[:id]).first[:intra_branch]
  end

  # Check if the requester is part of the project's main team
  def main_team_member?(pr, months_back)
    (committer_team(pr, months_back) + merger_team(pr, months_back)).uniq.include? requester(pr)
  end

  # Various statistics for the pull request. Returned as Hash with the following
  # keys: :lines_added, :lines_deleted, :files_added, :files_removed,
  # :files_modified, :files_touched, :src_files, :doc_files, :other_files.
  def pr_stats(pr, at_open = false)
    pr_id = pr[:id]
    raw_commits = commit_entries(pr_id, at_open)
    result = Hash.new(0)

    def file_count(commits, status)
      commits.map do |c|
        unless c['files'].nil?
          c['files'].reduce(Array.new) do |acc, y|
            if y['status'] == status then acc << y['filename'] else acc end
          end
        else
          []
        end
      end.flatten.uniq.size
    end

    def files_touched(commits)
      commits.map do |c|
        unless c['files'].nil?
          c['files'].map do |y|
            y['filename']
          end
        else
          []
        end
      end.flatten.uniq.size
    end

    def file_type(f)
      lang = Linguist::Language.find_by_filename(f)
      if lang.empty? then :data else lang[0].type end
    end

    def file_type_count(commits, type)
      commits.map do |c|
        unless c['files'].nil?
          c['files'].reduce(Array.new) do |acc, y|
            if file_type(y['filename']) == type then acc << y['filename'] else acc end
          end
        else
          []
        end
      end.flatten.uniq.size
    end

    def lines(commit, type, action)
      return 0 if commit['files'].nil?
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

  def test_diff_stats(from_sha, to_sha)

    from = git.lookup(from_sha)
    to = git.lookup(to_sha)

    diff = to.diff(from)

    added = deleted = 0
    state = :none
    diff.patch.lines.each do |line|
      if line.start_with? '---'
        file_path = line.strip.split(/---/)[1]
        next if file_path.nil?

        file_path = file_path[2..-1]
        next if file_path.nil?

        if test_file_filter.call(file_path)
          state = :in_test
        end
      end

      if line.start_with? '- ' and state == :in_test
        if test_case_filter.call(line)
          deleted += 1
        end
      end

      if line.start_with? '+ ' and state == :in_test
        if test_case_filter.call(line)
          added += 1
        end
      end

      if line.start_with? 'diff --'
        state = :none
      end
    end

    {:tests_added => added, :tests_deleted => deleted}
  end

  # Return a hash of file names and commits on those files in the
  # period between pull request open and months_back. The returned
  # results do not include the commits coming from the PR.
  def commits_on_pr_files(pr, months_back)

    oldest = Time.at(Time.at(pr[:created_at]).to_i - 3600 * 24 * 30 * months_back)
    pr_against = pull_req_entry(pr)['base']['sha']
    commits = commit_entries(pr[:id], at_open = true)

    commits_per_file = commits.flat_map { |c|
      unless c['files'].nil?
        c['files'].map { |f|
          [c['sha'], f['filename']]
        }
      else
        []
      end
    }.select{|x| x.size > 1}.group_by {|c|
      c[1]
    }

    commits_per_file.keys.reduce({}) do |acc, filename|
      commits_in_pr = commits_per_file[filename].map{|x| x[0]}

      walker = Rugged::Walker.new(git)
      walker.sorting(Rugged::SORT_DATE)
      walker.push(pr_against)

      commit_list = walker.take_while do |c|
        c.time > oldest
      end.reduce([]) do |acc1, c|
        if c.diff(paths: [filename.to_s]).size > 0 and
            not commits_in_pr.include? c.oid
          acc1 << c.oid
        end
        acc1
      end
      acc.merge({filename => commit_list})
    end
  end

  # Number of unique commits on the files changed by the pull request
  # between the time the PR was created and `months_back`
  # excluding those created by the PR
  def commits_on_files_touched(pr, months_back)
    commits_on_pr_files(pr, months_back).reduce([]) do |acc, commit_list|
      acc + commit_list[1]
    end.flatten.uniq.size
  end

  # Total number of commits on the project in the period up to `months` before
  # the pull request was opened. `exclude_pull_req` controls whether commits
  # from pull requests should be accounted for.
  def commits_last_x_months(pr, exclude_pull_req, months_back)
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
      and c.created_at > DATE_SUB(prh.created_at, INTERVAL #{months_back} MONTH)
      and pr.id=?
    QUERY

    if exclude_pull_req
      q << ' and not exists (select * from pull_request_commits prc1 where prc1.commit_id = c.id)'
    end

    db.fetch(q, pr[:id]).first[:num_commits]
  end

  # Total entropy introduced by PR
  def new_entropy(pr)
    files = commit_entries(pr[:id], at_open = true).flat_map{|x| x['files']}

    entropy_diffs = files.\
      select{ |f| ['modified', 'added'].include? f['status']}.\
      map{|x| unless x['patch'].nil? then entropy(x['patch'].gsub(/@@.*@@/,'')) else 0 end}

    # A2 Calc entropy for new versions of existing files
    del_entropies = files.\
      select{|f| f['status'] == 'deleted'}.\
      map{|x| entropy(x['patch'].gsub(/@@.*@@/,''))}

    (entropy_diffs - del_entropies).reduce(0){|acc, x| acc + x}
  end

  def project_entropy(pr)
    lslr(git.lookup(pr[:base_commit]).tree).\
      select{|f| f[:type] == :blob}.\
      map {|f| entropy(git.read(f[:oid]).data)}.\
      reduce(0){|acc, x| acc + x}
  end

  # Num of @uname mentions in the description
  # Modelling the results of: An Exploratory Study of @-mention in GitHub's Pull-requests
  # DOI: 10.1109/APSEC.2014.58
  def at_mentions_description(pr)
    pull_req = pull_req_entry(pr)
    unless pull_req['body'].nil?
      pull_req['body'].\
        gsub(/`.*?`/, '').\
        gsub(/[\w]*@[\w]+\.[\w]+/, '').\
        scan(/(@[a-zA-Z0-9]+)/).size
    else
      0
    end
  end

  # Num of @uname mentions in comments
  def at_mentions_comments(pr)
    issue_comments(pr[:login], pr[:project_name], pr[:github_id]).map do |ic|
      # Remove stuff between backticks (they may be code)
      # e.g. see comments in https://github.com/ReactiveX/RxScala/pull/166
      unless ic['body'].nil?
        ic['body'].\
            gsub(/`.*?`/, '').\
            gsub(/[\w]*@[\w]+\.[\w]+/, '')
      else
        0
      end
    end.map do |ic|
      ic.scan(/(@[a-zA-Z0-9]+)/).size
    end.reduce(0) do |acc, x|
      acc + x
    end
  end

  private

  def entropy(s)
    counts = Hash.new(0.0)
    s.each_char { |c| counts[c] += 1 }
    leng = s.length

    counts.values.reduce(0) do |entropy, count|
      freq = count / leng
      entropy - freq * Math.log2(freq)
    end
  end

  def pull_req_entry(pr)
    mongo['pull_requests'].find({:owner => pr[:login],
                                 :repo => pr[:project_name],
                                 :number => pr[:github_id]}).limit(1).first
  end

  # JSON objects for the commits included in the pull request
  def commit_entries(pr_id, at_open = false)
    if at_open
      q = <<-QUERY
        select c.sha as sha
        from pull_requests pr, pull_request_commits prc,
             commits c, pull_request_history prh
        where pr.id = prc.pull_request_id
        and prc.commit_id = c.id
        and prh.action = 'opened'
        and prh.pull_request_id = pr.id
        and c.created_at <= prh.created_at
        and pr.id = ?
      QUERY
    else
      q = <<-QUERY
        select c.sha as sha
        from pull_requests pr, pull_request_commits prc, commits c
        where pr.id = prc.pull_request_id
        and prc.commit_id = c.id
        and pr.id = ?
      QUERY
    end

    commits = db.fetch(q, pr_id).all

    commits.reduce([]){ |acc, x|
      a = mongo['commits'].find({:sha => x[:sha]}).limit(1).first

      if a.nil?
        a = github_commit(owner, repo, x)
      end

      acc << a unless a.nil?
      acc
    }.select{|c| c['parents'].size <= 1}
  end

  # Returns all comments for the issue sorted by creation date ascending
  def issue_comments(owner, repo, pr_id)
    mongo['issue_comments'].find(
        {'owner' => owner, 'repo' => repo, 'issue_id' => pr_id.to_i},
        {:fields => {'body' => 1, 'created_at' => 1, '_id' => 0},
         :sort   => {'created_at' => 1}}
    ).map { |x| x }

  end

  # Recursively get information from all files given a rugged Git tree
  def lslr(tree, path = '')
    all_files = []
    for f in tree.map { |x| x }
      f[:path] = path + '/' + f[:name]
      if f[:type] == :tree
        begin
          all_files << lslr(git.lookup(f[:oid]), f[:path])
        rescue StandardError => e
          log e
          all_files
        end
      else
        all_files << f
      end
    end
    all_files.flatten
  end

  # List of files in a project checkout. Filter is an optional binary function
  # that takes a file entry and decides whether to include it in the result.
  def files_at_commit(sha, filter = lambda { true })

    begin
      files = lslr(git.lookup(sha).tree)
      if files.size <= 0
        log "No files for commit #{sha}"
      end
      files.select { |x| filter.call(x) }
    rescue StandardError => e
      log "Cannot find commit #{sha} in base repo"
      []
    end
  end

  def count_lines(files, include_filter = lambda{|x| true})
    a = files.map do |f|
      stripped(f).lines.select do |x|
        not x.strip.empty?
      end.select do |x|
        include_filter.call(x)
      end.size
    end
    a.reduce(0){|acc,x| acc + x}
  end

  # Clone or update, if already cloned, a git repository
  def clone(user, repo, update = false)

    def spawn(cmd)
      proc = IO.popen(cmd, 'r')

      proc_out = Thread.new {
        while !proc.eof
          log "GIT: #{proc.gets}"
        end
      }

      proc_out.join
    end

    checkout_dir = File.join('repos', user, repo)

    begin
      repo = Rugged::Repository.new(checkout_dir)
      if update
        spawn("cd #{checkout_dir} && git pull")
      end
      repo
    rescue
      spawn("git clone git://github.com/#{user}/#{repo}.git #{checkout_dir}")
      Rugged::Repository.new(checkout_dir)
    end
  end

  # Load a commit from Github. Will return an empty hash if the commit does not exist.
  def github_commit(owner, repo, sha)
    parent_dir = File.join('commits', "#{owner}@#{repo}")
    commit_json = File.join(parent_dir, "#{sha}.json")
    FileUtils::mkdir_p(parent_dir)

    r = nil
    if File.exists? commit_json
      r = begin
        JSON.parse File.open(commit_json).read
      rescue
        # This means that the retrieval operation resulted in no commit being retrieved
        {}
      end
      return r
    end

    url = "https://api.github.com/repos/#{owner}/#{repo}/commits/#{sha}"
    log("Requesting #{url} (#{@remaining} remaining)")

    contents = nil
    begin
      r = open(url, 'User-Agent' => 'ghtorrent', 'Authorization' => "token #{token}")
      @remaining = r.meta['x-ratelimit-remaining'].to_i
      @reset = r.meta['x-ratelimit-reset'].to_i
      contents = r.read
      JSON.parse contents
    rescue OpenURI::HTTPError => e
      @remaining = e.io.meta['x-ratelimit-remaining'].to_i
      @reset = e.io.meta['x-ratelimit-reset'].to_i
      log "Cannot get #{url}. Error #{e.io.status[0].to_i}"
      {}
    rescue StandardError => e
      log "Cannot get #{url}. General error: #{e.message}"
      {}
    ensure
      File.open(commit_json, 'w') do |f|
        f.write contents unless r.nil?
        f.write '' if r.nil?
      end

      if 5000 - @remaining >= REQ_LIMIT
        to_sleep = @reset - Time.now.to_i + 2
        log "Request limit reached, sleeping for #{to_sleep} secs"
        sleep(to_sleep)
      end
    end
  end

  def src_files(sha)
    files_at_commit(sha, src_file_filter)
  end

  def src_lines(sha)
    count_lines(src_files(sha))
  end

  def test_files(sha)
    files_at_commit(sha, test_file_filter)
  end

  def test_lines(sha)
    count_lines(test_files(sha))
  end

  def num_test_cases(sha)
    count_lines(test_files(sha), test_case_filter)
  end

  def num_assertions(sha)
    count_lines(test_files(sha), assertion_filter)
  end

  # Return a f: filename -> Boolean, that determines whether a
  # filename is a test file
  def test_file_filter
    raise Exception.new("Unimplemented")
  end

  # Return a f: filename -> Boolean, that determines whether a
  # filename is a src file
  def src_file_filter
    raise Exception.new("Unimplemented")
  end

  # Return a f: buff -> Boolean, that determines whether a
  # line represents a test case declaration
  def test_case_filter
    raise Exception.new("Unimplemented")
  end

  # Return a f: buff -> Boolean, that determines whether a
  # line represents an assertion
  def assertion_filter
    raise Exception.new("Unimplemented")
  end

  def strip_comments(buff)
    raise Exception.new("Unimplemented")
  end

end

PullReqDataExtraction.run
#vim: set filetype=ruby expandtab tabstop=2 shiftwidth=2 autoindent smartindent:
