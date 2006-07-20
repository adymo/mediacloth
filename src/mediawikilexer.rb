#The lexer for MediaWiki language.
#
#Standalone usage:
# file = File.new("somefile", "r")
# input = file.read
# lexer = MediaWikiLexer.new
# lexer.tokenize(input)
#
#Inside RACC-generated parser:
# ...
# ---- inner ----
# attr_accessor :lexer
# def parse(input)
#     lexer.tokenize(input)
#     return do_parse
# end
# def next_token
#     return @lexer.lex
# end
# ...
# parser = MediaWikiParser.new
# parser.lexer = MediaWikiLexer.new
# parser.parse(input)
class MediaWikiLexer

    #Initialized the lexer with a match table.
    #
    #The match table tells the lexer which method to invoke
    #on given input char during "tokenize" phase.
    def initialize
        @position = 0
        @pair_stack = [[false, false]] #stack of tokens for which a pair should be found
        @list_stack = []
        @lexer_table = Hash.new(method(:match_other))
        @lexer_table["'"] = method(:match_italic_or_bold)
        @lexer_table["="] = method(:match_section)
        @lexer_table["["] = method(:match_link_start)
        @lexer_table["]"] = method(:match_link_end)
        @lexer_table[" "] = method(:match_space)
        @lexer_table["*"] = method(:match_list)
        @lexer_table["#"] = method(:match_list)
        @lexer_table[";"] = method(:match_list)
        @lexer_table[":"] = method(:match_list)
        @lexer_table["-"] = method(:match_line)
        @lexer_table["~"] = method(:match_signature)
        @lexer_table["h"] = method(:match_inline_link)
    end

    #Transforms input stream (string) into the stream of tokens.
    #Tokens are collected into an array of type [ [TOKEN_SYMBOL, TOKEN_VALUE], ..., [false, false] ].
    #This array can be given as input token-by token to RACC based parser with no
    #modification. The last token [false, false] inficates EOF.
    def tokenize(input)
        @tokens = []
        @cursor = 0
        @text = input
        @next_token = []

        #This tokenizer algorithm assumes that everything that is not
        #matched by the lexer is going to be :TEXT token. Otherwise it's usual
        #lexer algo which call methods from the match table to define next tokens.
        while (@cursor < @text.length)
            @current_token = [:TEXT, ''] unless @current_token
            @token_start = @cursor
            @char = @text[@cursor, 1]

            if @lexer_table[@char].call == :TEXT
                @current_token[1] += @text[@token_start, 1]
            else
                #skip empty :TEXT tokens
                @tokens << @current_token unless empty_text_token?
                @next_token[1] = @text[@token_start, @cursor - @token_start]
                @tokens << @next_token
                #hack to enable sub-lexing!
                if @sub_tokens
                    @tokens += @sub_tokens
                    @sub_tokens = nil
                end
                #end of hack!
                @current_token = nil
                @next_token = []
            end
        end
        #add the last TEXT token if it exists
        @tokens << @current_token if @current_token and not empty_text_token?

        #RACC wants us to put this to indicate EOF
        @tokens << [false, false]
        @tokens
    end

    #Returns the next token from the stream. Useful for RACC parsers.
    def lex
        token = @tokens[@position]
        @position += 1
        return token
    end


private
    #-- ================== Match methods ================== ++#

    #Matches anything that was not matched. Returns :TEXT to indicate
    #that matched characters should go into :TEXT token.
    def match_other
        @cursor += 1
        return :TEXT
    end

    #Matches italic or bold symbols:
    # "'''"     { return :BOLD; }
    # "''"      { return :ITALIC; }
    def match_italic_or_bold
        if @text[@cursor, 3] == "'''" and @pair_stack.last[0] != :ITALICSTART
            matchBold
            @cursor += 3
            return
        end
        if @text[@cursor, 2] == "''"
            matchItalic
            @cursor += 2
            return
        end
        match_other
    end

    def matchBold
        if @pair_stack.last[0] == :BOLDSTART
            @next_token[0] = :BOLDEND
            @pair_stack.pop
        else
            @next_token[0] = :BOLDSTART
            @pair_stack.push @next_token
        end
    end

    def matchItalic
        if @pair_stack.last[0] == :ITALICSTART
            @next_token[0] = :ITALICEND
            @pair_stack.pop
        else
            @next_token[0] = :ITALICSTART
            @pair_stack.push @next_token
        end
    end

    #Matches sections
    # "=+"  { return SECTION; }
    def match_section
        if (@text[@cursor-1, 1] == "\n") or (@pair_stack.last[0] == :SECTION)
            i = 0
            i += 1 while @text[@cursor+i, 1] == "="
            @cursor += i
            @next_token[0] = :SECTION

            if @pair_stack.last[0] == :SECTION
                @pair_stack.pop
            else
                @pair_stack.push @next_token
            end
        else
            match_other
        end
    end

    #Matches start of the hyperlinks
    # "[["      { return INTLINKSTART; }
    # "["       { return LINKSTART; }
    def match_link_start
        if @text[@cursor, 2] == "[["
            @next_token[0] = :INTLINKSTART
            @pair_stack.push @next_token
            @cursor += 2
        elsif @text[@cursor, 1] == "[" and html_link?(@cursor+1)
            @next_token[0] = :LINKSTART
            @pair_stack.push @next_token
            @cursor += 1
        else
            match_other
        end
    end

    #Matches end of the hyperlinks
    # "]]"      { return INTLINKEND; }
    # "]"       { return LINKEND; }
    def match_link_end
        if @text[@cursor, 2] == "]]" and @pair_stack.last[0] == :INTLINKSTART
            @next_token[0] = :INTLINKEND
            @pair_stack.pop
            @cursor += 2
        elsif @text[@cursor, 1] == "]" and @pair_stack.last[0] == :LINKSTART
            @next_token[0] = :LINKEND
            @pair_stack.pop
            @cursor += 1
        else
            match_other
        end
    end

    #Matches inlined unformatted html link
    # "http://[^\s]*"   { return [ LINKSTART TEXT LINKEND]; }
    def match_inline_link
        #if no link start token was detected and the text starts with http://
        #then it's the inlined unformatted html link
        if html_link?(@cursor) and @pair_stack.last[0] != :INTLINKSTART and
                @pair_stack.last[0] != :LINKSTART
            @next_token[0] = :LINKSTART
            linkText = extract_till_whitespace
            @sub_tokens = []
            @sub_tokens << [:TEXT, linkText]
            @sub_tokens << [:LINKEND, ']']
            @cursor += linkText.length
            @token_start = @cursor
        else
            match_other
        end
    end

    #Matches space to find preformatted areas which start with a space after a newline
    # "\n\s[^\n]*"     { return PRE; }
    def match_space
        if at_start_of_line?
            match_untill_eol
            @next_token[0] = :PRE
            strip_ws_from_token_start
        else
            match_other
        end
    end

    #Matches any kind of list by using sublexing technique. MediaWiki lists are context-sensitive
    #therefore we need to do some special processing with lists. The idea here is to strip
    #the leftmost symbol indicating the list from the group of input lines and use separate
    #lexer to process extracted fragment.
    def match_list
        if at_start_of_line?
            list_id = @text[@cursor, 1]
            sub_text = extract_list_contents(list_id)
            extracted = 0

            #hack to tokenize everything inside the list
            @sub_tokens = []
            sub_lines = ""
            @sub_tokens << [:LI_START, ""]
            sub_text.each do |t|
                extracted += 1
                if text_is_list? t
                    sub_lines += t
                else
                    if not sub_lines.empty?
                        @sub_tokens += sub_lex(sub_lines)
                        sub_lines = ""
                    end
                    if @sub_tokens.last[0] != :LI_START
                        @sub_tokens << [:LI_END, ""]
                        @sub_tokens << [:LI_START, ""]
                    end
                    @sub_tokens += sub_lex(t.lstrip)
                end
            end
            if not sub_lines.empty?
                @sub_tokens += sub_lex(sub_lines)
                @sub_tokens << [:LI_END, ""]
            else
                @sub_tokens << [:LI_END, ""]
            end

            #end of hack
            @cursor += sub_text.length + extracted
            @token_start = @cursor

            case
                when list_id == "*"
                    @next_token[0] = :UL_START
                    @sub_tokens << [:UL_END, ""]
                when list_id == "#"
                    @next_token[0] = :OL_START
                    @sub_tokens << [:OL_END, ""]
                when list_id == ";", list_id == ":"
                    @next_token[0] = :DL_START
                    @sub_tokens << [:DL_END, ""]
            end

        else
            match_other
        end
    end

    #Matches the line until \n
    def match_untill_eol
        val = @text[@cursor, 1]
        while (val != "\n") and (!val.nil?)
            @cursor += 1
            val = @text[@cursor, 1]
        end
        @cursor += 1
    end

    #Matches hline tag that start with "-"
    # "\n----"      { return HLINE; }
    def match_line
        if at_start_of_line? and @text[@cursor, 4] == "----"
            @next_token[0] = :HLINE
            @cursor += 4
        else
            match_other
        end
    end

    #Matches signature
    # "~~~~~"      { return SIGNATURE_DATE; }
    # "~~~~"      { return SIGNATURE_FULL; }
    # "~~~"      { return SIGNATURE_NAME; }
    def match_signature
        if @text[@cursor, 5] == "~~~~~"
            @next_token[0] = :SIGNATURE_DATE
            @cursor += 5
        elsif @text[@cursor, 4] == "~~~~"
            @next_token[0] = :SIGNATURE_FULL
            @cursor += 4
        elsif @text[@cursor, 3] == "~~~"
            @next_token[0] = :SIGNATURE_NAME
            @cursor += 3
        else
            match_other
        end
    end

    #-- ================== Helper methods ================== ++#

    #Checks if the token is placed at the start of the line.
    def at_start_of_line?
        if @cursor == 0 or @text[@cursor-1, 1] == "\n"
            true
        else
            false
        end
    end

    #Checks if the text at position contains the start of the html link
    def html_link?(position)
        return @text[position, 7] == 'http://'
    end

    #Adjusts @token_start to skip leading whitespaces
    def strip_ws_from_token_start
        @token_start += 1 while @text[@token_start, 1] == " "
    end

    #Returns true if the TEXT token is empty or contains newline only
    def empty_text_token?
        @current_token == [:TEXT, ''] or @current_token == [:TEXT, "\n"]
    end

    #Returns true if the text is a list, i.e. starts with one of #;*: symbols
    #that indicate a list
    def text_is_list?(text)
        return text =~ /^[#;*:].*/
    end

    #Runs sublexer to tokenize sub_text
    def sub_lex(sub_text)
        sub_lexer = MediaWikiLexer.new
        sub_tokens = sub_lexer.tokenize(sub_text)
        sub_tokens.pop
        sub_tokens
    end

    #Extracts the text from current cursor position till the next whitespace
    def extract_till_whitespace
        i = @cursor
        text = ""
        while i < @text.length
            curr = @text[i, 1]
            if (curr == "\n") or (curr == "\t") or (curr == " ")
                break
            end
            text += curr
            i += 1
        end
        text
    end

    #Extract list contents of list type set by list_id variable.
    #Example list:
    # *a
    # **a
    #Extracted list with id "*" will look like:
    # a
    # *a
    def extract_list_contents(list_id)
        i = @cursor+1
        list = ""
        while i < @text.length
            curr = @text[i, 1]
            if (curr == "\n") and (@text[i+1, 1] != list_id)
                list+=curr
                break
            end
            list += curr unless (curr == list_id) and (@text[i-1, 1] == "\n")
            i += 1
        end
        list
    end

end

