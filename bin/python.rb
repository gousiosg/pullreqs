module PythonData

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
      buff = repo.blob(f[:sha]).data
      cases = buff.scan(/\s*def\s* test_(.*)\(.*\):/).size
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
      cases = repo.blob(f[:sha]).data.lines.select{|l| not l.match(/assert/).nil?}
      acc + cases.size
    end
    @ds_cache ||= {} # Hacky optimization to avoid memory problems
    ds_tests + normal_tests
  end

  def test_lines(pr_id)
    count_sloc(test_files(pr_id))
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
    count_sloc(src_files(pr_id))
  end

  def test_file_filter
    lambda { |f|
      path = if f.class == Hash then f[:path] else f end
      # http://pytest.org/latest/goodpractises.html#conventions-for-python-test-discovery
      path.end_with?('.py') and
          (not path.match(/test_.+\.py/i).nil? or not path.match(/.+_test.py/i).nil?)
    }
  end

  def ml_comment_regexps
    [/["']{3}(.+?)["']{3}/m]
  end

  def sl_comment_regexp
    /^\s*#/
  end

  private

  def docstrings(pr_id)
    @ds_cache ||= {}
    if @ds_cache[pr_id].nil?
      docstr = (src_files(pr_id) + test_files(pr_id)).flat_map do |f|
          buff = repo.blob(f[:sha]).data
          buff.scan(ml_comment_regexps[0])
          end
      @ds_cache[pr_id] = docstr.flatten
    end
    @ds_cache[pr_id]
  end
end
