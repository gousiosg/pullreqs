#
# (c) 2012 -- 2014 Georgios Gousios <gousiosg@gmail.com>
#
# BSD licensed, see LICENSE in top level dir
#

module CData

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
        f[:path].end_with?('.c') or f[:path].end_with?('.h')
      }
    )
  end

  def src_lines(pr_id)
    count_sloc(src_files(pr_id))
  end

  def test_file_filter
    lambda {|x| false}
  end

  private

  def count_sloc(files)
    files.map { |f|
      buff = repo.blob(f[:sha]).data
      # Count lines except empty ones
      count_file_lines(buff.lines, lambda{|l| not l.strip.empty?}) -
        count_single_line_comments(buff.lines, /^\s*\/\//) -
        count_multiline_comments(buff.lines, /\/\*(?:.|[\r\n])*?\*\//)
    }.reduce(0){|acc, x| acc + x}
  end
end
