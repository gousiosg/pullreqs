#
# (c) 2012 -- 2014 Georgios Gousios <gousiosg@gmail.com>
#
# BSD licensed, see LICENSE in top level dir
#

require 'comment_stripper'

module ScalaData

  include CommentStripper

  def num_test_cases(pr_id)
    count_lines(test_files(pr_id), lambda{|l|
      not l.match(/@Test/).nil? or           # JUnit
          not l.match(/ in\s*{/).nil? or     # specs2
          not l.match(/ it[\s({]+"/).nil? or # scalatest bdd tests
          not l.match(/ test[\s({]+"/).nil?  # scalatest unit tests
    })
  end

  def num_assertions(pr_id)
    count_lines(test_files(pr_id), lambda{|l|
      not l.match(/[.\s]assert[\s({]+/).nil? or          # JUnit, scalatest
          not l.match(/[.\s]must[\s({]+/).nil? or        # scalatest
          not l.match(/[.\s]should[\s({]+/).nil?        # scalatest, specs2
    })
  end

  def test_lines(pr_id)
    count_lines(test_files(pr_id))
  end

  def test_files(pr_id)
    files_at_commit(pr_id, test_file_filter)
  end

  def src_files(pr_id)
    files_at_commit(pr_id,
      lambda { |f|
        path = if f.class == Hash then f[:path] else f end
        not path.include?('/test/') and
            (path.end_with?('.java') or path.end_with?('.scala'))
      }
    )
  end

  def src_lines(pr_id)
    count_lines(src_files(pr_id))
  end

  def test_file_filter
    lambda { |f|
      path = if f.class == Hash then f[:path] else f end
      path.include?('/test/') and
        (path.end_with?('.java') or path.end_with?('.scala'))
    }
  end

  def strip_comments(buff)
    strip_c_style_comments(buff)
  end

end
