#
# (c) 2016 -- 2017 Georgios Gousios <gousiosg@gmail.com>
#

require_relative 'comment_stripper'

# Supported test frameworks: gotest, GoConvey
# Supported assertion types: testify, gotest, GoConvey
module GoData

  include CommentStripper

  def test_file_filter

    # https://golang.org/pkg/go/build/
    # http://stackoverflow.com/questions/25161774/what-are-conventions-for-filenames-in-go
    lambda do |f|
      path = if f.class == Hash then f[:path] else f end
      path.end_with?('_test.go')
    end
  end

  def src_file_filter
    lambda do |f|
      path = if f.class == Hash then f[:path] else f end
      path.end_with?('.go') and not test_file_filter.call(path)
    end
  end

  def test_case_filter
    lambda do |l|
      gotest_test_case?(l) or
          goConvey_test_case?(l)
    end
  end

  def assertion_filter
    lambda do |l|
      gotest_assertion?(l) or
        goConvey_assertion?(l) or
          testify_assertion?(l)
    end
  end

  def strip_comments(buff)
    strip_c_style_comments(buff)
  end

  def gotest_test_case?(l)
    # https://golang.org/doc/faq#How_do_I_write_a_unit_test
    # http://stackoverflow.com/questions/11689485/which-characters-are-allowed-in-a-function-struct-interface-name

    not l.match(/func\s*Test[[[:alpha:]]_]+\s*\(\s*\*testing\.T\s*\)/).nil?
  end

  def goConvey_test_case?(l)
    # https://github.com/smartystreets/goconvey/wiki/Composition
    not l.match(/Convey\s*\(/).nil?
  end

  def gotest_assertion?(l)
    # match all assertion failure cases from: https://golang.org/pkg/testing/
    not l.match(/(.)?((Fatal|Error)f?|Fail(Now)?)\s*\(/).nil?
  end

  def goConvey_assertion?(l)
    not l.match(/So\s*\(.*,\s*Should.*/).nil?
  end

  def testify_assertion?(l)
    not l.match(/(([Aa](ssert)?\.)|(^|\s))((Not)?Equal|(No)?Error|(Not)?Contains|(Not)?Panics|(Not)?Nil)/).nil?
  end

end
