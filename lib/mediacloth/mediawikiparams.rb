require 'singleton'

#MediaWiki parser parameter handler object.
#
#Stores and gives access to various parser settings and
#parser environment variables.
class MediaWikiParams

    #The name of the wiki page author
    attr_accessor :author

    def initialize
        @author = "Creator"
    end

    def time
        (@time || Time.now.utc).strftime("%a %b %d, %Y %H:%M")
    end

    def time=(t)
        @time = t
    end

end
