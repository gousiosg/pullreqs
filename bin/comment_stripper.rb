#
# (c) 2012 -- 2014 Georgios Gousios <gousiosg@gmail.com>
#
# BSD licensed, see LICENSE in top level dir
#

module CommentStripper

  def strip_shell_style_comments(buff)
    in_comment = false
    out = []
    buff.each_byte do |b|
      case b
        when '#'.getbyte(0)
          in_comment = true
        when "\r".getbyte(0)
        when "\n".getbyte(0)
          in_comment = false
          unless in_comment
            out << b
          end
        else
          unless in_comment
            out << b
          end
      end
    end
    out.pack('c*')
  end

  def strip_c_style_comments(buff)
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
