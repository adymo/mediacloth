require 'mediacloth/mediawikilexer'
require 'mediacloth/mediawikiparser'
require 'mediacloth/mediawikihtmlgenerator'
require 'mediacloth/mediawikilinkhandler'
require 'mediacloth/mediawikitemplatehandler'

require 'test/unit'
require 'testhelper'

class HTMLGenerator_Test < Test::Unit::TestCase

    class << self
      include TestHelper
    end

    test_files("html") do |input,result, name|
      name =~ /([0-9]+)$/
      define_method("test_input_#{$1}") do
        assert_generates(result, input, nil, name)
      end
    end

    def test_http_urls_in_internal_links
      html = generate('[[http://www.google.com]]', MediaWikiLinkHandler.new)
      assert_equal html, '<p><a href="http://www.google.com">http://www.google.com</a></p>'
      html = generate('[[https://www.google.com]]', MediaWikiLinkHandler.new)
      assert_equal html, '<p><a href="https://www.google.com">https://www.google.com</a></p>'
    end

    def test_punctuation_at_the_end_of_absolute_links
      html = generate('http://example.com.', MediaWikiLinkHandler.new)
      assert_equal html, '<p><a href="http://example.com">http://example.com</a>.</p>'
      html = generate('http://example.com...', MediaWikiLinkHandler.new)
      assert_equal html, '<p><a href="http://example.com">http://example.com</a>...</p>'
      html = generate('http://example.com,', MediaWikiLinkHandler.new)
      assert_equal html, '<p><a href="http://example.com">http://example.com</a>,</p>'
      html = generate('http://example.com:', MediaWikiLinkHandler.new)
      assert_equal html, '<p><a href="http://example.com">http://example.com</a>:</p>'
      html = generate('http://example.com;', MediaWikiLinkHandler.new)
      assert_equal html, '<p><a href="http://example.com">http://example.com</a>;</p>'
      html = generate('http://example.com-', MediaWikiLinkHandler.new)
      assert_equal html, '<p><a href="http://example.com">http://example.com</a>-</p>'
    end

    def test_punctuation_at_the_end_of_internal_links
      html = generate('[http://example.com/page. Example]', MediaWikiLinkHandler.new)
      assert_equal html, '<p><a href="http://example.com/page.">Example</a></p>'
      html = generate('[http://example.com/page- Example]', MediaWikiLinkHandler.new)
      assert_equal html, '<p><a href="http://example.com/page-">Example</a></p>'
    end

    def test_uses_element_attributes_from_link_handler
      html = generate('[[InternalLink|This is just an internal link]]', ClassEmptyLinkHandler.new)
      expected1 = '<p><a class="empty" href="http://www.example.com/wiki/InternalLink">This is just an internal link</a></p>'
      expected2 = '<p><a href="http://www.example.com/wiki/InternalLink" class="empty">This is just an internal link</a></p>'
      assert (html == expected1 or html == expected2)
    end

    def test_accepts_url_only_link_handlers
      assert_generates '<p><a href="http://www.example.com/wiki/InternalLink/">This is just an internal link</a></p>',
                       '[[InternalLink|This is just an internal link]]',
                       UrlOnlyLinkHandler.new
    end

    def test_prefers_url_from_attributes_when_provided_with_ambiguous_link_info
      html = generate('[[InternalLink|This is just an internal link]]', AmbiguousLinkHandler.new)
      expected1 = '<p><a rel="nofollow" href="http://www.example.com/wiki/InternalLink">This is just an internal link</a></p>'
      expected2 = '<p><a href="http://www.example.com/wiki/InternalLink" rel="nofollow">This is just an internal link</a></p>'
      assert (html == expected1 or html == expected2)
    end

    def test_allows_specification_of_all_attributes
      html = generate('[[MyLink|Here is my link]]', LinkAttributeHandler.new)
      expected1 = '<p><a href="http://www.mysite.com/MyLink" id="123">Here is my link</a></p>'
      expected2 = '<p><a id="123" href="http://www.mysite.com/MyLink">Here is my link</a></p>'
      assert (html == expected1 or html == expected2)
    end

    def test_allows_full_customization_of_link_tags
      assert_generates '<p><span class="link">This doesn\'t even render into a real link</span></p>',
                       "[[AnotherLink|This doesn't even render into a real link]]",
                        FullLinkHandler.new
    end

    def test_handles_category_links
      assert_generates '<p><a class="category" href="http://www.mywiki.net/wiki/Category:Foo">More articles on Foo</a></p>',
                       "[[:Category:Foo|More articles on Foo]]",
                        CategoryLinkHandler.new
    end

    def test_handles_category_directives
      assert_generates '<p><div id="catlinks">This page belongs to the <a class="category" href="http://www.mywiki.net/wiki/Category:Foo">Foo category</a></div></p>',
                       "[[Category:Foo]]",
                        CategoryDirectiveHandler.new
    end

    def test_table_with_column_attributes
      assert_generates "<table cellpadding=\"5\" border=\"1\"><tr><td>a\n</td></tr>\n<tr><td  colspan=\"4\" align=\"center\" style=\"background:#ffdead;\"> b\n</td></tr>\n</table>\n",
        "{|\n|a\n|-\n| colspan=\"4\" align=\"center\" style=\"background:#ffdead;\"| b\n|}"
    end

    def test_table_with_column_attributes_cellspacing_and_border
      assert_generates "<table cellpadding=\"10\" border=\"5\"><tr><td>a\n</td></tr>\n<tr><td  colspan=\"4\" align=\"center\" style=\"background:#ffdead;\"> b\n</td></tr>\n</table>\n",
        "{|cellpadding=\"10\" border=\"5\"\n|a\n|-\n| colspan=\"4\" align=\"center\" style=\"background:#ffdead;\"| b\n|}"
    end

    def test_table_with_column_attributes_cellspacing_and_border_and_style
      assert_generates "<table cellspacing=\"0\" cellpadding=\"5\" style=\"border-collapse:collapse\"><tr><td>a\n</td></tr>\n<tr><td  colspan=\"4\" align=\"center\" style=\"background:#ffdead;\"> b\n</td></tr>\n</table>\n",
        "{|cellspacing=\"0\" cellpadding=\"5\" style=\"border-collapse:collapse\"\n|a\n|-\n| colspan=\"4\" align=\"center\" style=\"background:#ffdead;\"| b\n|}"
    end

    def test_table_without_column_attributes
      assert_generates "<table cellpadding=\"5\" border=\"1\"><tr><td> a\n</td><td> b\n</td></tr>\n</table>\n",
        "{|\n| a\n| b\n|}"
    end

private

  def assert_generates(result, input, link_handler=nil, message=nil)
      assert_equal(result, generate(input, link_handler), message)
   end

   def generate(input, link_handler = nil)
      parser = MediaWikiParser.new
      parser.lexer = MediaWikiLexer.new
      ast = parser.parse(input)
      generator = MediaWikiHTMLGenerator.new
      generator.link_handler = link_handler if link_handler
      params = MediaWikiParams.new
      params.time = Time.utc(2000, 1, 1, 1, 1, 1, 1)
      generator.params = params
      generator.parse(ast)
      generator.html
   end
end

class LinkAttributeHandler < MediaWikiLinkHandler
  def link_attributes_for(page)
    { :href => "http://www.mysite.com/#{page}", :id => '123' }
  end
end

class ClassEmptyLinkHandler < MediaWikiLinkHandler
  def link_attributes_for(resource)
    {:class => 'empty', :href => "http://www.example.com/wiki/#{resource}"}
  end
end

class UrlOnlyLinkHandler < MediaWikiLinkHandler
  def url_for(resource)
    "http://www.example.com/wiki/#{resource}/"
  end
end

class AmbiguousLinkHandler < MediaWikiLinkHandler
  def url_for(resource)
    "http://www.somewhereelse.net"
  end

  def link_attributes_for(resource)
    {:rel => 'nofollow', :href => "http://www.example.com/wiki/#{resource}"}
  end
end

class FullLinkHandler < MediaWikiLinkHandler
  def link_for(page, text)
    "<span class=\"link\">#{text}</span>"
  end
end

class CategoryLinkHandler 
  def link_for_category(locator, text)
    %(<a class="category" href="http://www.mywiki.net/wiki/Category:#{locator}">#{text}</a>)
  end
end

class CategoryDirectiveHandler
  def category_add(name, sort)
    %(<div id="catlinks">This page belongs to the <a class="category" href="http://www.mywiki.net/wiki/Category:#{name}">#{name} category</a></div>)
  end
end


