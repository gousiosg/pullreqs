#
# (c) 2012 -- 2014 Georgios Gousios <gousiosg@gmail.com>
#
# BSD licensed, see LICENSE in top level dir
#

require 'comment_stripper'

module PythonData

  include CommentStripper

  def num_test_cases(pr_id)
      ds_tests = docstrings(pr_id).reduce(0) do |acc, docstring|
        in_test = false
        tests = 0
        docstring.lines.each do |x|

          if in_test == false
            if x.match(/^\s+>>>/)
              in_test = true
              tests += 1
            end
          else
            in_test = false unless x.match(/^\s+>>>/)
          end
        end
        acc + tests
      end

    normal_tests = test_files(pr_id).reduce(0) do |acc, f|
      cases = stripped(f).scan(/\s*def\s* test_(.*)\(.*\):/).size
      acc + cases
    end
    ds_tests + normal_tests
  end

  def num_assertions(pr_id)
    ds_tests = docstrings(pr_id).reduce(0) do |acc, docstring|
      in_test = false
      asserts = 0
      docstring.lines.each do |x|

        if in_test == false
          if x.match(/^\s+>>>/)
            in_test = true
          end
        else
          asserts += 1
          in_test = false unless x.match(/^\s+>>>/)
        end
      end
      acc + asserts
    end

    normal_tests = test_files(pr_id).reduce(0) do |acc, f|
      cases = stripped(f).lines.select{|l| not l.match(/assert/).nil?}
      acc + cases.size
    end
    Thread.current[:ds_cache] = {} # Hacky optimization to avoid memory problems
    ds_tests + normal_tests
  end

  def test_lines(pr_id)
    count_lines(test_files(pr_id))
  end

  def test_files(pr_id)
    files_at_commit(pr_id,
      lambda { |f|
        f[:path].end_with?('.py') and test_file_filter.call(f[:path])
      })
  end

  def src_files(pr_id)
    files_at_commit(pr_id,
      lambda { |f|
        f[:path].end_with?('.py') and not test_file_filter.call(f[:path])
      }
    )
  end

  def src_lines(pr_id)
    count_lines(src_files(pr_id))
  end

  def test_file_filter
    lambda { |f|
      path = if f.class == Hash then f[:path] else f end
      # http://pytest.org/latest/goodpractises.html#conventions-for-python-test-discovery
      # Path points to a python file named as foo_test.py or test_foo.py or test.py
      # or it contains a test directory
      path.end_with?('.py') and(
          (
            not path.match(/test_.+/i).nil? or
            not path.match(/.+_test/i).nil? or
            not path.match(/tests?/i).nil?
          ) or (
            not path.match(/test\//).nil?
          )
      )
    }
  end

  def strip_comments(buff)
    strip_python_multiline_comments(strip_shell_style_comments(buff))
  end

  def strip_python_multiline_comments(buff)
    out = []
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
    out.flatten.reduce(''){|acc, x| acc + x}
  end

  def ml_comment_regexps
    [/["']{3}(.+?)["']{3}/m]
  end

  private

  def docstrings(pr_id)
    Thread.current[:ds_cache] ||= {}
    if Thread.current[:ds_cache][pr_id].nil?
      docstr = (src_files(pr_id) + test_files(pr_id)).flat_map do |f|
          buff = repo.read(f[:oid]).data
          buff.scan(ml_comment_regexps[0])
          end
      Thread.current[:ds_cache][pr_id] = docstr.flatten
    end
    Thread.current[:ds_cache][pr_id]
  end
end
