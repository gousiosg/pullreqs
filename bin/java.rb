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
    files_at_commit(pr_id, test_file_filter)
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

  def test_file_filter()
    lambda { |f|
      path = if f.class == Hash then f[:path] else f end
      path.end_with?('.java') and path.include?("/test/")
    }
  end

end