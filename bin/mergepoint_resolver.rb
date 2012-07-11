require 'rubygems'
require 'pullreqs'

class MergePointResolver < PullReqs::Command

  include GHTorrent::Settings

  def pre

  end

  def go(connection)
    channel = AMQP::Channel.new(connection)
    exchange = channel.topic(config(:amqp_exchange),
                             :durable => true,
                             :auto_delete => false)

    queue = channel.queue("#{h}s", {:durable => true}).bind(exchange, :routing_key => GHTorrent::ROUTEKEY_PULL_REQUEST)

  end
end

MergePointResolver.run