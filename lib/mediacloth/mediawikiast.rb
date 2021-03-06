#AST Node
class AST
    attr_accessor :contents
    attr_accessor :parent
    attr_accessor :children
    attr_accessor :index
    attr_accessor :length

    def initialize(index = 0,length = 0)
        @children = []
        @parent = nil
        @contents = ""
        @index = index
        @length = length
    end
end

#The root node for all wiki parse trees
class WikiAST < AST

end

#The node to represent paragraph with text inside
class ParagraphAST < AST
end

#The node to represent paragraph with text pasted into wiki
class PasteAST < AST
end

#The node to represent a simple or formatted text
#with more AST nodes inside.
class FormattedAST < AST
    #Currently recognized formatting: :Bold, :Italic, :Link, :InternalLink, :HLine
    attr_accessor :formatting
end

#The node to represent a simple or formatted text
class TextAST < FormattedAST
    #Currently recognized formatting: :Link, :InternalLink, :HLine
end

#The node to represent a simple Mediawiki link.
class LinkAST < AST
    #The link's URL
    attr_accessor :url
    attr_accessor :link_type
end

#The node to represent a Mediawiki internal link
class InternalLinkAST < AST
    #Holds the link locator, which is composed of a resource name only (e.g. the
    #name of a wiki page)
    attr_accessor :locator
end

#The node to represent a Mediawiki category link
class CategoryLinkAST < AST
    #Holds the category locator, which is composed of a category name only
    #(e.g. the name of the category)
    attr_accessor :locator
end

#The node to represent a MediaWiki resource reference (embedded images, videos,
#etc.)
class ResourceLinkAST < AST
    #The resource prefix that indicates the type of resource (e.g. an image
    #resource is prefixed by "Image")
    attr_accessor :prefix
    #The resource locator
    attr_accessor :locator
end

class InternalLinkItemAST < AST
end

#The node to represent a table
class TableAST < AST
    attr_accessor :options
end

#The node to represent a table
class TableRowAST < AST
    attr_accessor :options
end

#The node to represent a table
class TableCellAST < AST
    #the type of cell, :head or :body
    attr_accessor :type
    attr_accessor :attributes
end

#The node to represent a list
class ListAST < AST
    #Currently recognized types: :Bulleted, :Numbered
    attr_accessor :list_type
end

#The node to represent a list item
class ListItemAST < AST
end

# The node to represent a leading term in a dictionary list
class ListTermAST < AST
end

# The node to represent a definition in a dictionary list
class ListDefinitionAST < AST
end

#The node to represent a section
class SectionAST < AST
    #The level of the section (1,2,3...) that would correspond to
    #<h1>, <h2>, <h3>, etc.
    attr_accessor :level
end

#The node to represent a preformatted contents
class PreformattedAST < AST
    attr_accessor :indented
end

#The node to represent an XHTML element and its contents
class ElementAST < AST
    attr_accessor :name, :attributes
end

# The node to represent special Mediawiki keywords, such as __TOC__. The text
# attribute contains the entire string inbetween '__' and '__'.
class KeywordAST < AST
    attr_accessor :text
end

# The node to represent templates and pre-defined (or user-defined) variables, such as
# {{Date}}.
class TemplateAST < AST
    attr_accessor :template_name
end

# The node to represent template parameter
class TemplateParameterAST < AST
    attr_accessor :parameter_name   #not used atm
    attr_accessor :parameter_value
end

#The node to represent categories to which this page belongs
class CategoryAST < AST
    #Holds the name of the category
    attr_accessor :locator
    #Holds the string the page is to be sorted as
    attr_accessor :sort_as
end
