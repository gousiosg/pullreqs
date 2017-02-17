#
# (c) 2012 -- 2015 Georgios Gousios <gousiosg@gmail.com>
#

require_relative 'comment_stripper'

module RubyData

  include CommentStripper

  def src_file_filter
    lambda do |f|
      path = if f.class == Hash then f[:path] else f end
      path.end_with?('.rb') and not test_file_filter.call(f)
    end
  end

  def test_file_filter
    lambda do |f|
      path = if f.class == Hash then f[:path] else f end
      path.end_with?('.rb') and (
          (path.include?('test/') or
          path.include?('tests/') or
          path.include?('spec/')) and
      not path.include?('lib/'))
    end
  end

  def assertion_filter
    lambda { |l|
      (not l.match(/assert/).nil? or       # RUnit assertions
          not l.match(/\.should/).nil? or  # RSpec assertions
          not l.match(/\.expect/).nil? or  # RSpec and shoulda expectations
          not l.match(/\.must_/).nil?  or  # Minitest expectations
          not l.match(/\.wont_/).nil?  or  # Minitest expectations
          not l.match(/\s+should\s*[({]?/).nil? or # RSpec matchers
          not l.match(/\s+expect\s*[({]?/).nil?) # RSpec matchers
    }
  end

  def test_case_filter
    lambda { |l|
      not l.match(/^ *def +.*test.*/).nil? or             #Runit tests
          not l.match(/^\s*should\s+.*\s+(do|{)/).nil? or # Shoulda tests
          not l.match(/^\s*it\s+.*\s+(do|{)/).nil? }      # Rspec, Minitest tests
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
