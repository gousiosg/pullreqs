module RubyData

  def num_test_cases(pr_id)
    test_method_line = /^ *def +.*test.*/
    shoulda_line = /^\ *should\ +.*(do|{)/

    test_files(pr_id).map{ |f|
      repo.blob(f[:sha]).data.lines.select { |l|
        not (l.match(test_method_line).nil? && l.match(shoulda_line).nil?)
      }.size
    }.reduce(0){|acc,x| acc + x}

  end

  def test_lines(pr_id)

    comment_line = /^\s*#/

    test_files(pr_id).map{ |f|
      repo.blob(f[:sha]).data.lines.select {|l|
        l.match(comment_line).nil?
      }.size
    }.reduce(0){|acc,x| acc + x}

  end

  def test_files(pr_id)
    files_at_commit(pr_id, lambda{|f| f[:path].include?("test/") && f[:path].end_with?('.rb')})
  end

  def src_files(pr_id)
    files_at_commit(pr_id, lambda{|f| not f[:path].include?("test/") && f[:path].end_with?('.rb')})
  end

  def src_lines(pr_id)

  end

  def num_assertions(pr_id)

  end
end