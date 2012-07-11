require 'rubygems'
require 'trollop'
require 'daemons'
require 'etc'
require 'amqp'
require 'ghtorrent'

# Base class for all GHTorrent command line utilities. Provides basic command
# line argument parsing and command bootstraping support. The order of
# initialization is the following:
# prepare_options
# validate
# pre
# go

module PullReqs
  class Command < GHTorrent::Command

    class << self
      def run(args = ARGV)
        command = new(args)
        command.process_options
        command.validate

        begin
          command.pre

          Signal.trap('INT') {
            info ("Received SIGINT, exiting")
            AMQP.stop { EM.stop }
          }
          Signal.trap('TERM') {
            info ("Received SIGTERM, exiting")
            AMQP.stop { EM.stop }
          }

          AMQP.start(:host => config(:amqp_host),
                     :port => config(:amqp_port),
                     :username => config(:amqp_username),
                     :password => config(:amqp_password)) do |connection|

            command.go connection
          end
        rescue => e
          STDERR.puts e.message
          if command.options.verbose
            STDERR.puts e.backtrace.join("\n")
          else
            STDERR.puts e.backtrace[0]
          end
          exit 1
        end
      end
    end

    # Code to run before entering the AMQP loop
    def pre

    end

    # The actual command code.
    def go(connection)
    end

  end
end
# vim: set sta sts=2 shiftwidth=2 sw=2 et ai :