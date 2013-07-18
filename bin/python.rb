module PythonData

  def num_test_cases(pr_id)
    0
  end

  def num_assertions(pr_id)
    0
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
      #See: http://nose.readthedocs.org/en/latest/writing_tests.html
      path.end_with?('.py') and not path.match(/(?:^|[\\b_\\.-])[Tt]est/).nil?
    }
  end

  def ml_comment_regexps
    [/["']{3}(.+?)["']{3}/m]
  end

  def sl_comment_regexp
    /^\s*#/
  end
end
