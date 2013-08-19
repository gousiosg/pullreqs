module ScalaData

  def num_test_cases(pr_id)
    test_files(pr_id).map do |f|
      repo.blob(f[:sha]).data
    end.map do |x|
      remove_comments(x)
    end.flat_map do |f|
      f.lines.map{|x| x}
    end.select do |l|
      not l.match(/@Test/).nil? or           # JUnit
          not l.match(/ in\s*{/).nil? or     # specs2
          not l.match(/ it[\s({]+"/).nil? or # scalatest bdd tests
          not l.match(/ test[\s({]+"/).nil?  # scalatest unit tests
    end.size
  end

  def num_assertions(pr_id)
    test_files(pr_id).map do |f|
      repo.blob(f[:sha]).data
    end.map do |x|
      remove_comments(x)
    end.flat_map do |f|
      f.lines.map{|x| x}
    end.select do |l|
      not l.match(/[.\s]assert[\s({]+/).nil? or          # JUnit, scalatest
          not l.match(/[.\s]must[\s({]+/).nil? or        # scalatest
          not l.match(/[.\s]should[\s({]+/).nil?        # scalatest, specs2
    end.size
  end

  def test_lines(pr_id)
    count_sloc(test_files(pr_id))
  end

  def test_files(pr_id)
    files_at_commit(pr_id, test_file_filter)
  end

  def src_files(pr_id)
    files_at_commit(pr_id,
      lambda { |f|
        f[:path].end_with?('.scala') and not f[:path].include?('/test/')
      }
    )
  end

  def src_lines(pr_id)
    count_sloc(src_files(pr_id))
  end

  def test_file_filter
    lambda { |f|
      path = if f.class == Hash then f[:path] else f end
      path.include?('/test/') and
        (path.end_with?('.java') or path.end_with?('.scala'))
    }
  end

  def remove_comments(buff)
    in_ml_comment = in_sl_comment = may_start_comment = may_end_comment = false
    out = []
    buff.each_byte do |b|
      case b
        when '/'.getbyte(0)
          if may_start_comment
            unless in_ml_comment
              in_sl_comment = true
            end
          elsif may_end_comment
            in_ml_comment = false
            may_end_comment = false
          else
            may_start_comment = true
          end
        when '*'.getbyte(0)
          if may_start_comment
            in_ml_comment = true
            may_start_comment = false
          else
            may_end_comment = true
          end
        when "\r".getbyte(0)
        when "\n".getbyte(0)
          in_sl_comment = false
          unless in_sl_comment or in_ml_comment
            out << b
          end
        else
          unless in_sl_comment or in_ml_comment
            out << b
          end
          may_end_comment = may_start_comment = false
      end
    end
    out.pack('c*')
  end
end