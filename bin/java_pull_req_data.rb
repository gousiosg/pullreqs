module JavaData

  def src_files(pr_id)
    files_at_commit(pr_id,
                    lambda { |f|
                      f[:path].end_with?('.java') and
                      not f[:path].include?("/test/")
                    }
    )
  end

  def src_lines(pr_id)
    count_sloc(src_files(pr_id))
  end

  def test_files(pr_id)
    files_at_commit(pr_id,
                    lambda { |f|
                        f[:path].end_with?('.java')  and
                        f[:path].include?("/test/")
                    }
    )
  end

  def test_lines(pr_id)
    count_sloc(test_files(pr_id))
  end

  def num_test_cases(pr_id)
    test_files(pr_id).map {|f|
      buff = repo.blob(f[:sha]).data

      junit4 = buff.lines.select{|l| not l.match(/@Test/).nil?}.size

      if junit4 == 0 #Try Junit 3 style
        buff.scan(
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
      # Count lines except empty ones
      count_file_lines(buff.lines, lambda{|l| not l.strip.empty?}) -
          count_single_line_comments(buff, /^\s*\/\//) -
          count_multiline_comments(buff, /\/\*(?:.|[\r\n])*?\*\//)
    }.reduce(0){|acc, x| acc + x}
  end

end