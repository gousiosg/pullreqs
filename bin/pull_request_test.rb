require 'ghtorrent'
require 'json'
require 'rugged'
require 'fileutils'

class PullRequestTest < GHTorrent::Command

  def validate
    super
    Trollop::die "no input specified" unless args[0] && !args[0].empty?
  end

  def go

    pull_request = JSON.parse(File.open(args[0]).read)

    base_git = pull_request['base']['repo']['clone_url']
    base_fullname = pull_request['base']['repo']['full_name']

    head_git = pull_request['head']['repo']['clone_url']
    head_fullname = pull_request['head']['repo']['full_name']

    if pull_request['merged_at'].nil?
      puts "Pull request not merged yet"
      return
    end

    scratch = "/var/tmp"
    FileUtils.mkdir_p(File.join(scratch, base_fullname))
    FileUtils.mkdir_p(File.join(scratch, head_fullname))

    `git clone #{base_git} #{File.join(scratch, base_fullname)}`
    `git clone #{head_git} #{File.join(scratch, head_fullname)}`

  end

end

PullRequestTest.run
