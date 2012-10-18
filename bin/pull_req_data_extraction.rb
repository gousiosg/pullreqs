#!/usr/bin/env ruby

require 'rubygems'
require 'bundler'
require 'ghtorrent'
require 'time'
require 'linguist'
require 'grit'

require 'java_pull_req_data'
require 'ruby_pull_req_data'

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
    Trollop::die "Three arguments required" unless !args[2].nil?
  end

  def logger
    @ght.logger
  end

  def db
    @db ||= @ght.get_db
    @db
  end

  def mongo
    @mongo ||= connect(:mongo, settings)
    @mongo
  end

  def repo
    @repo ||= clone(ARGV[0], ARGV[1])
    @repo
  end

  def go

    @ght ||= GHTorrent::Mirror.new(settings)

    user_entry = @ght.transaction{@ght.ensure_user(ARGV[0], false, false)}

    if user_entry.nil?
      Trollop::die "Cannot find user #{owner}"
    end

    repo_entry = @ght.transaction{@ght.ensure_repo(ARGV[0], ARGV[1], false, false, false)}

    if repo_entry.nil?
      Trollop::die "Cannot find repository #{owner}/#{repo}"
    end

    case ARGV[2]
      when "ruby" then self.extend(RubyData)
      when "java" then self.extend(JavaData)
    end

    print "project_name, github_id, pull_req_id, created_at," <<
          "merged_at, lifetime_minutes, " <<
          "team_size_at_merge, num_commits, num_comments, " <<
          "files_added, files_deleted, files_modified, " <<
          "src_files, doc_files, other_files, " <<
          "lines_addded, lines_deleted, " <<
          "total_commits_last_month, main_repo_commits_last_month, " <<
          "commits_on_files_touched, " <<
          "requester_followers, num_test_cases, test_lines\n"

    pull_reqs(repo_entry).each do |pr|
      begin
        per_pull_req(pr)
      rescue Exception => e
        STDERR.puts "Error processing pull_request #{pr[:id]}: #{e.message}"
      end
    end
  end

  def clone(user, repo)

    def spawn(cmd)
      proc = IO.popen(cmd, "r")

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
      spawn("cd #{checkout_dir} && git pull")
      repo
    rescue
      spawn("git clone git://github.com/#{user}/#{repo}.git #{checkout_dir}")
      Grit::Repo.new(checkout_dir)
    end
  end

  def pull_reqs(project)
    q = <<-QUERY
    select p.name as project_name, pr.id, pr.pullreq_id as github_id,
           a.created_at as created_at, b.created_at as merged_at,
           timestampdiff(minute, a.created_at, b.created_at) as lifetime_minutes
    from pull_requests pr, projects p,
         pull_request_history a, pull_request_history b
    where p.id = pr.base_repo_id
	    and a.pull_request_id = pr.id
      and a.pull_request_id = b.pull_request_id
      and a.action='opened' and b.action='merged'
	    and a.created_at < b.created_at
      and p.id = ?
	  group by pr.id
    order by merged_at desc
    QUERY
    db.fetch(q, project[:id]).all
  end

  def per_pull_req(pr)

    stats = pr_stats(pr[:id])

    print pr[:project_name], ", ",
          pr[:github_id], ", ",
          pr[:id], ", ",
          Time.at(pr[:created_at]).to_i, ", ",
          Time.at(pr[:merged_at]).to_i, ", ",
          pr[:lifetime_minutes], ", ",
          team_size_at_merge(pr[:id], 3)[0][:teamsize], ", ",
          num_commits(pr[:id])[0][:commit_count], ", ",
          num_comments(pr[:id])[0][:comment_count], ", ",
          stats[:files_added], ", ",
          stats[:files_deleted], ", ",
          stats[:files_modified], ", ",
          stats[:src_files], ", ",
          stats[:doc_files], ", ",
          stats[:other_files], ", ",
          stats[:lines_added], ", ",
          stats[:lines_deleted], ", ",
          commits_last_month(pr[:id], false)[0][:num_commits], ", ",
          commits_last_month(pr[:id], true)[0][:num_commits], ", ",
          commits_on_files_touched(pr[:id], Time.at(Time.at(pr[:merged_at]).to_i - 3600 * 24 * 30)), ", ",
          requester_followers(pr[:id])[0][:num_followers], ", ",
          num_test_cases(pr[:id]), ", ",
          test_lines(pr[:id]),
          "\n"
  end

  def team_size_at_merge(pr_id, interval_months)
    q = <<-QUERY
    select count(distinct author_id) as teamsize
    from projects p, commits c, project_commits pc, pull_requests pr,
         pull_request_history prh
    where p.id = pc.project_id
      and pc.commit_id = c.id
      and p.id = pr.base_repo_id
      and prh.pull_request_id = pr.id
      and not exists (select * from pull_request_commits prc1 where prc1.commit_id = c.id)
      and prh.action = 'merged'
      and c.created_at < prh.created_at
      and c.created_at > DATE_SUB(prh.created_at, INTERVAL #{interval_months} MONTH)
      and pr.id=?;
    QUERY
    not_zero(if_empty(db.fetch(q, pr_id).all, :teamsize), :teamsize)
  end

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

  def num_comments(pr_id)
    q = <<-QUERY
    select count(*) as comment_count
    from pull_requests pr, pull_request_comments prc
    where pr.id = prc.pull_request_id
	    and pr.id = ?
    group by prc.pull_request_id
    QUERY
    if_empty(db.fetch(q, pr_id).all, :comment_count)
  end

  def requester_followers(pr_id)
    q = <<-QUERY
    select count(f.follower_id) as num_followers
    from pull_requests pr, followers f, pull_request_history prh
    where pr.user_id = f.user_id
      and prh.pull_request_id = pr.id
      and prh.action = 'merged'
      and f.created_at < prh.created_at
      and pr.id = ?
    QUERY
    if_empty(db.fetch(q, pr_id).all, :num_followers)
  end

  def commit_entries(pr_id)
    q = <<-QUERY
    select c.sha as sha
    from pull_requests pr, pull_request_commits prc, commits c
    where pr.id = prc.pull_request_id
    and prc.commit_id = c.id
    and pr.id = ?
    QUERY
    commits = db.fetch(q, pr_id).all

    commits.map{ |x|
      mongo.find(:commits, {:sha => x[:sha]})[0]
    }
  end

  def pr_stats(pr_id)

    raw_commits = commit_entries(pr_id)
    result = Hash.new(0)

    def file_count(commit, status)
      commit['files'].reduce(0) { |acc, y|
        if y['status'] == status then acc + 1 else acc end
      }
    end

    def file_type(f)
      lang = Linguist::Language.detect(f, nil)
      if lang.nil? then :data else lang.type end
    end

    def file_type_count(commit, type)
      commit['files'].reduce(0) { |acc, y|
        if file_type(y['filename']) == type then acc + 1 else acc end
      }
    end

    raw_commits.each{ |x|
      result[:lines_added] += x['stats']['additions']
      result[:lines_deleted] += x['stats']['deletions']
      result[:files_added] += file_count(x, "added")
      result[:files_removed] += file_count(x, "removed")
      result[:files_modified] += file_count(x, "modified")
      result[:files_touched] += (file_count(x, "modified") + file_count(x, "added") + file_count(x, "removed"))
      result[:src_files] += file_type_count(x, :programming)
      result[:doc_files] += file_type_count(x, :markup)
      result[:other_files] += file_type_count(x, :data)
    }
    result
  end

  def commits_on_files_touched(pr_id, oldest)
    commit_entries(pr_id).map { |c|
      c['files'].map{ |f|
        size = repo.log(c['sha'], f['filename']).find_all{ |l|
          #STDERR.print(f['filename'], " ", l.id, " ", l.authored_date," ", oldest, "\n")
          l.authored_date > oldest
        }.size
        #STDERR.print(f['filename'], " #{size} commits\n")
        size
      }
    }.flatten.reduce(0){|acc,x| acc + x}
  end

  def commits_last_month(pr_id, exclude_pull_req)
    q = <<-QUERY
    select count(c.id) as num_commits
    from projects p, commits c, project_commits pc, pull_requests pr,
         pull_request_history prh
    where p.id = pc.project_id
      and pc.commit_id = c.id
      and p.id = pr.base_repo_id
      and prh.pull_request_id = pr.id
      and prh.action = 'merged'
      and c.created_at < prh.created_at
      and c.created_at > DATE_SUB(prh.created_at, INTERVAL 1 MONTH)
      and pr.id=?
    QUERY

    if exclude_pull_req
      q << " and not exists (select * from pull_request_commits prc1 where prc1.commit_id = c.id)"
    end
    q << ";"

    not_zero(if_empty(db.fetch(q, pr_id).all, :num_commits), :num_commits)
  end

  private

  def files_at_commit(pr_id, filter)
    q = <<-QUERY
    select c.sha
    from pull_requests p, commits c
    where c.id = p.base_commit_id
    and p.id = ?
    QUERY

    base_commit = db.fetch(q, pr_id).all[0][:sha]
    files = repo.lstree(base_commit, :recursive => true)
    return files if filter.nil?

    files.select{|x| filter.call(x)}
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
end

PullReqDataExtraction.run
#vim: set filetype=ruby expandtab tabstop=2 shiftwidth=2 autoindent smartindent:
