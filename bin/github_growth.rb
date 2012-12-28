#!/usr/bin/env ruby

require 'mongo'
require 'time'
require 'date'

mongo = Mongo::Connection.new("dutiil", 27017)
db = mongo.db("github")
events = db['events'] 

puts "date,forks,pull_requests,issues,stars,follows"

start_year = Time.parse("01-01-2012 00:00").to_datetime 
end_year =  Time.parse("01-01-2013 00:00").to_datetime

(start_year..end_year).each do |day|
  date_filter = {'_id' => {'$gte' => BSON::ObjectId.from_time(day.to_time),
                 '$lt' => BSON::ObjectId.from_time((day + 1).to_time)}}
  counts = events.find(date_filter).reduce(Hash.new(0)) do |acc,e|
    case e['type']
    when "IssuesEvent"
      acc[e['type']] += 1 if e['action'] == "opened"
    else
      acc[e['type']] += 1
    end
    acc
  end

  puts "#{day.to_s},#{counts['PushEvent']},#{counts['ForkEvent']},#{counts['PullRequestEvent']},#{counts['IssuesEvent']},#{counts['WatchEvent']},#{counts['FollowEvent']}"

end
