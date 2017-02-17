#
# (c) 2012 -- 2017 Georgios Gousios <gousiosg@gmail.com>
#

require_relative 'comment_stripper'

  # Supported testing frameworks: unittest, pytest and nose
module PythonData

  include CommentStripper

  def test_file_filter
    lambda do |f|
      path = if f.class == Hash then f[:path] else f end
      # http://pytest.org/latest/goodpractises.html#conventions-for-python-test-discovery
      # Path points to a python file named as foo_test.py or test_foo.py or test.py
      # or it contains a test directory
      path.end_with?('.py') and
      (
        not path.match(/test_.+/i).nil? or
        not path.match(/.+_test/i).nil? or
        not path.match(/test.py/i).nil? or
        not path.match(/tests?\//i).nil?
      )
    end
  end

  def src_file_filter
    lambda do |f|
      path = if f.class == Hash then f[:path] else f end
      path.end_with?('.py') and not test_file_filter.call(path)
    end
  end

  def test_case_filter
    lambda do |l|
      # http://doc.pytest.org/en/latest/goodpractices.html#test-discovery
      not l.match(/\s*def\s* test_(.*)\(.*\):/).nil?
    end
  end

  def assertion_filter
    lambda do |l|
      # https://docs.python.org/2/library/unittest.html#assert-methods
      # http://nose.readthedocs.io/en/latest/writing_tests.html#test-packages
      not l.match(/assert([A-Z]\w*)?/).nil? or
          pytest_assertion?(l)
    end
  end

  def pytest_assertion?(l)
    # http://doc.pytest.org/en/latest/builtin.html
    not l.match(/(with)?\s*(pytest\.)?raises/).nil? or
        not l.match(/(pytest.)?approx/).nil?
  end

  def strip_comments(buff)
    strip_python_multiline_comments(strip_shell_style_comments(buff))
  end

  def strip_python_multiline_comments(buff)
    out        = []
    in_comment = false
    buff.lines.each do |line|
      if line.match(/^\s*["']{3}/)
        in_comment = !in_comment
        next
      end

      unless in_comment
        out << line
      end
    end
    out.flatten.reduce('') { |acc, x| acc + x }
  end

end
