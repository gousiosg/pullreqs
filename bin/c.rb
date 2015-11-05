#
# (c) 2012 -- 2015 Georgios Gousios <gousiosg@gmail.com>
#

require 'comment_stripper'

module CData

  include CommentStripper

  def src_file_filter

  end

  def test_file_filter

  end

  def assertion_filter

  end

  def test_case_filter

  end

  def strip_comments(buff)
    strip_c_style_comments(buff)
  end

end
