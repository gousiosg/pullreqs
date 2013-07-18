module RubyData

  def num_test_cases(pr_id)

    filter = lambda {|l| l.match(/^ *def +.*test.*/).nil? or #Runit tests
        l.match(/^\s*should\s+.*\s+(do|{)/).nil? or # Shoulda tests
        l.match(/^\s*it\s+.*\s+(do|{)/).nil?} # Rspec tests

    count_lines(test_files(pr_id), filter)
  end

  def num_assertions(pr_id)
    count_lines(test_files(pr_id), lambda { |l|
      l.match(/assert/).nil? or             # RUnit assertions
          l.match(/\.should/).nil? or   # RSpec assertions
          l.match(/\.expect/).nil?      # RSpec expectations
    })
  end

  def test_lines(pr_id)
    count_sloc(test_files(pr_id))
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
    count_sloc(src_files(pr_id))
  end

  def test_file_filter
    lambda do |f|
      path = if f.class == Hash then f[:path] else f end
      (path.include?('test/') && path.end_with?('.rb')) ||
      (path.include?('spec/') && path.end_with?('.rb'))
    end
  end

  def ml_comment_regexps
    [/^=begin(.+?)=end/m, /__END__(.*)$/m]
  end

  def sl_comment_regexp
    /^\s*#/
  end
end