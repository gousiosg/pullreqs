#!/usr/bin/env ruby

require 'mongo'
require 'time'
require 'date'

mongo = Mongo::Connection.new("dutiil", 27017)
db = mongo.db("github")
events = db['events'] 

puts "date,pushes,forks,pull_requests,issues,stars,follows,creates"

#start_year = Time.parse("01-01-2012 00:00").to_datetime 
#end_year =  Time.parse("01-01-2013 00:00").to_datetime

#(start_year..end_year).each do |day|
#  date_filter = {'_id' => {'$gte' => BSON::ObjectId.from_time(day.to_time),
#                 '$lt' => BSON::ObjectId.from_time((day + 1).to_time)}}
#  counts = events.find(date_filter).reduce(Hash.new(0)) do |acc,e|
#    case e['type']
#    when "IssuesEvent"
#      acc[e['type']] += 1 if e['action'] == "opened"
#    else
#      acc[e['type']] += 1
#    end
#    acc
#  end

acc = Hash.new()
events.find({},{}).each do|e|
  next if e.nil?
  next if e.empty?

  d = Time.parse(e['created_at']).strftime("%Y-%m-%d")
  t = e['type']

  if acc[d].nil? then acc[d] = {} end

  val = case e['type']
        when "CreateEvent"
          if e['payload']['ref_type'] == "repository"
            if acc[d][t].nil? then 1 else acc[d][t] += 1 end
          else
            next
          end
        when "IssuesEvent"
          if e['payload']['action'] == "opened"
            if acc[d][t].nil? then 1 else acc[d][t] += 1 end
          else
            next
          end
        else
          if acc[d][t].nil? then 1 else acc[d][t] += 1 end
        end

  if acc[d][t].nil? then acc[d][t] = Hash.new() end
  acc[d][t] = val 
end

acc.keys.sort{|a,b| a<=>b}.each do |k|
  counts = acc[k]
  puts "#{k},#{counts['PushEvent']},#{counts['ForkEvent']},#{counts['PullRequestEvent']},#{counts['IssuesEvent']},#{counts['WatchEvent']},#{counts['FollowEvent']},#{counts['CreateEvent']}"
end


#end
