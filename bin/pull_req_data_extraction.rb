#!/usr/bin/env ruby

require 'rubygems'
require 'bundler'
require 'ghtorrent'
require 'time'

class PullReqDataExtraction < GHTorrent::Command

  def prepare_options(options)
    options.banner <<-BANNER
Extract data for pull requests for a given repository

#{command_name} owner repo

    BANNER
  end

  def validate
    super
    Trollop::die "Two arguments are required" unless args[0] && !args[0].empty?
  end

  def logger
    @ght.logger
  end

  def db
    @db ||= @ght.get_db
    @db
  end

  def go

    @ght ||= GHTorrent::Mirror.new(settings)

    user_entry = @ght.transaction{@ght.ensure_user(ARGV[0], false, false)}

    if user_entry.nil?
      Trollop::die "Cannot find user #{owner}"
    end

    user = user_entry[:login]

    repo_entry = @ght.transaction{@ght.ensure_repo(ARGV[0], ARGV[1], false, false, false)}

    if repo_entry.nil?
      Trollop::die "Cannot find repository #{owner}/#{repo}"
    end

    print "project_id, pull_req_id, created_at, merged_at\n"

    get_pull_reqs(repo_entry).each do |pr|
      print pr[:project_id], ", ",
            pr[:id], ", ",
            Time.at(pr[:created_at]).to_i, ", ",
            Time.at(pr[:merged_at]).to_i, ", ",
            "\n"
    end
  end

  def get_pull_reqs(project)

    q = <<-QUERY
    select p.id as project_id, pr.id, a.created_at as created_at, b.created_at as merged_at
    from pull_requests pr, projects p,
         pull_request_history a, pull_request_history b
    where p.id = pr.base_repo_id
	    and a.pull_request_id = pr.id
      and a.pull_request_id = b.pull_request_id
      and a.action='opened' and b.action='merged'
	    and a.created_at < b.created_at
      and p.id = ?
	  group by pr.id
    QUERY

    db.fetch(q, project[:id]).all
  end
end

PullReqDataExtraction.run
#vim: set filetype=ruby expandtab tabstop=2 shiftwidth=2 autoindent smartindent:
