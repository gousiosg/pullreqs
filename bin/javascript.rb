#
# (c) 2012 -- onwards Georgios Gousios <gousiosg@gmail.com>
#

require 'comment_stripper'

module JavascriptData

  include CommentStripper

  def src_file_filter
    lambda do |f|
      path = if f.class == Hash then f[:path] else f end
      path.end_with?('.js') and
            path.match('min.js').nil? and
            not test_file_filter.call(f)
    end
  end

  def test_file_filter
    lambda do |f|
      path = if f.class == Hash then f[:path] else f end
      path.end_with?('.js') and
          (
            path.include?('spec/') or
            path.include?('test/') or
            path.include?('tests/') or
            path.include?('testing/') or
            path.include?('__tests__') or
            not path.match(/.+_test/i).nil?)
    end
  end

  def assertion_filter
    lambda { |l|
      (not l.match(/assert/).nil? or            #chai, node.js
          not l.match(/\.?[e|E]xpect/).nil? or  # Jasmine
          not l.match(/\.?[s|S]hould/).nil? or  # Mocha
          not l.match(/([e|E]qual\s*\(|ok\s*\()/).nil?) #qunit
    }
  end

  def test_case_filter
    lambda { |l|
      not l.match(/it\('.*',/).nil? or               # Jasmine, Mocha, chai
      not l.match(/".*"\s*:\s*function\(/).nil?      # d3.js and friends
    }
  end

  def strip_comments(buff)
    strip_c_style_comments(buff)
  end

end
