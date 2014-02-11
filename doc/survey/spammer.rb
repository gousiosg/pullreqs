#!/usr/bin/env ruby

require 'mysql2'
require 'net/smtp'
require 'erb'
require 'ostruct'
require 'set'

email_tmpl = File.open('email.erb').read

mysql = Mysql2::Client.new(:host => "127.0.0.1",
                           :username => ARGV[1],
                           :password => ARGV[2],
                           :database => "ghtorrent")

if ARGV[0].nil?
  puts 'A list of repositories is required'
  exit(1)
end

@used_email_addresses = SortedSet.new
@num_send = 0

def q_top_mergers(owner, repo)
      "select u1.login as login, u1.name as name, u1.company as company,
              u1.email as email, count(*) as count
       from pull_requests pr, projects p, users u,
            pull_request_history prh, users u1
       where pr.id = prh.pull_request_id
        and u.id = p.owner_id
        and prh.action='merged'
        and prh.actor_id = u1.id
        and pr.base_repo_id = p.id
<<<<<<< Updated upstream
        and year(prh.created_at) = 2013
        and p.name = '#{repo}'
        and u.login = '#{owner}'
=======
        and p.name = '#{owner}'
        and u.login = '#{repo}'
>>>>>>> Stashed changes
      group by u1.id
      order by count(*) desc
      limit 10"
end

def q_top_submitters(owner, repo)
      "select u1.login as login, u1.name as name, u1.company as company,
              u1.email as email, count(*) as count
       from pull_requests pr, projects p, users u,
            pull_request_history prh, users u1
       where pr.id = prh.pull_request_id
        and u.id = p.owner_id
        and prh.action='opened'
        and prh.actor_id = u1.id
        and pr.base_repo_id = p.id
        and year(prh.created_at) = 2013
        and p.name = '#{repo}'
        and u.login = '#{owner}'
      group by u1.id
      order by count(*) desc
      limit 10"
end

def render_erb(template, locals)
  ERB.new(template).result(OpenStruct.new(locals).instance_eval { binding })
end

def send_spam(db, tmpl,  owner, repo)
  top_mergers = db.query(q_top_mergers(owner, repo), :symbolize_keys => true)
  top_submitters = db.query(q_top_submitters(owner, repo), :symbolize_keys => true)

  #puts "#{top_mergers.size} mergers, #{top_submitters.size} submitters for #{owner}/#{repo}"
  
  top_mergers.to_a.reverse[0..1].each do |m|

    if m[:email].nil? or @used_email_addresses.include? m[:email]
      next
    end

    email = render_erb(tmpl, :name => m[:name], :email => m[:email], :login => m[:login],
                 :role => 'integrators', :repo => "#{owner}/#{repo}",
                 :link => 'https://www.surveymonkey.com/s/pullreq-handlers',
                 :perflink => "http://ghtorrent.org/pullreq-perf/#{owner}-#{repo}/")

    Net::SMTP.start('localhost', 25, 'ghtorrent.org') do |smtp|
       #smtp.send_message(email, 'Georgios Gousios <G.Gousios@tudelft.nl>',
       #                 m[:email])
      @num_send += 1
      puts "Sent email to #{m[:email]}, merger at #{owner}/#{repo}, sent #{@num_send}"
    end

    @used_email_addresses << m[:email]
  end

  top_submitters.to_a.reverse[0..1].each do |m|

    if m[:email].nil? or @used_email_addresses.include? m[:email]
      next
    end

    email = render_erb(tmpl, :name => m[:name], :email => m[:email], :login => m[:login],
                 :role => 'integrators', :repo => "#{owner}/#{repo}",
                 :link => 'https://www.surveymonkey.com/s/pullreqs-contrib',
                 :perflink => "http://ghtorrent.org/pullreq-perf/#{owner}-#{repo}/")

    Net::SMTP.start('localhost', 25, 'ghtorrent.org') do |smtp|
      #smtp.send_message(email, 'Georgios Gousios <G.Gousios@tudelft.nl>',
      #                  m[:email])
      puts "Sent email to #{m[:email]}, contributor to #{owner}/#{repo}, sent #{@num_send}"
      @num_send += 1
    end

    @used_email_addresses << m[:email]
  end

end

if File.exists? 'used-emails.txt'
  File.open("used-emails.txt").each do |line|
    @used_email_addresses << line.strip
  end
end

File.open(ARGV[0]).each do |line|
  owner, repo = line.split(/ /)
  send_spam(mysql, email_tmpl, owner.strip, repo.strip)
end

File.open("used-emails.txt", 'w+') do |f|
  @used_email_addresses.each do |email|
    f.write("#{email}\n")
  end
end
