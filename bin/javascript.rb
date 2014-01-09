#
# (c) 2012 -- 2014 Georgios Gousios <gousiosg@gmail.com>
#
# BSD licensed, see LICENSE in top level dir
#

module JavascriptData

  def num_test_cases(pr_id)
    0
  end

  def num_assertions(pr_id)
    0
  end

  def test_lines(pr_id)
    0
  end

  def test_files(pr_id)
    0
  end

  def src_files(pr_id)
    files_at_commit(pr_id,
      lambda { |f|
        f[:path].end_with?('.js') 
      }
    )
  end

  def src_lines(pr_id)
    count_sloc(src_files(pr_id))
  end

  def test_file_filter
    lambda {|x| false}
  end

end
