#
# (c) 2012 -- 2014 Georgios Gousios <gousiosg@gmail.com>
#
# BSD licensed, see LICENSE in top level dir
#

require 'comment_stripper'

module RubyData

  include CommentStripper

  def num_test_cases(pr_id)

    filter = lambda { |l|
       not l.match(/^ *def +.*test.*/).nil? or             #Runit tests
          not l.match(/^\s*should\s+.*\s+(do|{)/).nil? or # Shoulda tests
          not l.match(/^\s*it\s+.*\s+(do|{)/).nil? }      # Rspec, Minitest tests

    count_lines(test_files(pr_id), filter)
  end

  def num_assertions(pr_id)
    count_lines(test_files(pr_id), lambda { |l|
      (not l.match(/assert/).nil? or       # RUnit assertions
          not l.match(/\.should/).nil? or  # RSpec assertions
          not l.match(/\.expect/).nil? or  # RSpec and shoulda expectations
          not l.match(/\.must_/).nil?  or  # Minitest expectations
          not l.match(/\.wont_/).nil?  or  # Minitest expectations
          not l.match(/\s+should\s*[({]?/).nil? or # RSpec matchers
          not l.match(/\s+expect\s*[({]?/).nil?) # RSpec matchers
    })
  end

  def test_lines(pr_id)
    count_lines(test_files(pr_id))
  end

  def test_files(pr_id)
    files_at_commit(pr_id, test_file_filter)
  end

  def src_files(pr_id)
    files_at_commit(pr_id,
                    lambda{ |f|
                      not f[:path].include?('test/') and
                      not f[:path].include?('spec/') and
                          f[:path].end_with?('.rb')
                    }
    )
  end

  def src_lines(pr_id)
    count_lines(src_files(pr_id))
  end

  def test_file_filter
    lambda do |f|
      path = if f.class == Hash then f[:path] else f end
      path.end_with?('.rb') && (path.include?('test/') ||
          path.include?('tests/') ||
          path.include?('spec/'))
    end
  end

  def strip_comments(buff)
    strip_ruby_multiline_comments(strip_shell_style_comments(buff))
  end

  def strip_ruby_multiline_comments(buff)
    out = []
    in_comment = false
    buff.lines.each do |line|
      if line.start_with?('=begin')
        in_comment = true
      end

      if line.start_with?('=end')
        in_comment = false
      end

      if line.start_with?('__END__')
        break
      end

      unless in_comment
        out << line
      end
    end
    out.flatten.reduce(''){|acc, x| acc + x}
  end

end
