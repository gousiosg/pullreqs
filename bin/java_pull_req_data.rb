module JavaData

  def src_files(pr_id)
    files_at_commit(pr_id,
                    lambda { |f|
                      not f[:path].include?("/test/") and
                          f[:path].end_with?('.java')
                    }
    )
  end

  def src_lines(pr_id)
    count_sloc(src_files(pr_id))
  end

  def test_files(pr_id)
    files_at_commit(pr_id,
                    lambda { |f|
                          f[:path].include?("/test/") and
                          f[:path].end_with?('.java')
                    }
    )
  end

  def test_lines(pr_id)
    count_sloc(test_files(pr_id))
  end

  def num_test_cases(pr_id)
    test_files(pr_id).map {|f|
      buff = repo.blob(f[:sha]).data

      junit4 = count_lines(test_files(pr_id), lambda{|l| not l.match(/@Test/).nil?})

      if junit4 == 0 #Try Junit 3 style
        buff.blob(f[:sha]).data.scan(
          /(public|protected|private|static|\s) +[\w<>\[\]]+\s+(\w+) *\([^\)]*\) *(\{?|[^;])/
        ).map{ |x|
          if x[1].match(/^test/) then 1 else 0 end
        }.reduce(0){|acc, x| acc + x}
      else
        junit4
      end
    }.reduce(0){|acc, x| acc + x}
  end

  def num_assertions(pr_id)
    count_lines(test_files(pr_id), lambda{|l| not l.match(/assert/).nil?})
  end

  private

  def count_sloc(files)
    files.map { |f|
      buff = repo.blob(f[:sha]).data
      # Count lines except empty and single line comments
      count_file_lines(buff.lines, lambda{|l| l.match(/^\s*\/\//).nil?}) -
          # Count multiline comments
          count_multiline_comments(buff)
    }.reduce(0){|acc, x| acc + x}
  end

  def count_multiline_comments(file_str)
    file_str.scan(/\/\*(?:.|[\r\n])*?\*\//).map { |x|
      x.lines.count
    }.reduce(0){|acc, x| acc + x}
  end
end