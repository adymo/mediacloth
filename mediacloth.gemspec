require 'rubygems'

SPEC = Gem::Specification.new do |s|
    s.name      = "mediacloth"
    s.version   = "0.0.2"
    s.author    = "Pluron Inc."
    s.email     = "support@pluron.com"
    s.homepage  = "http://mediacloth.rubyforge.org/"
    s.platform  = Gem::Platform::RUBY
    s.summary   = "A MediaWiki syntax parser and HTML generator."
    candidates  = Dir.glob("{bin,docs,lib,test}/**/*")
    s.files     = candidates.delete_if do |item|
                    item.include?(".svn") || item.include?("rdoc")
                  end
    s.require_path      = "lib"
    s.autorequire       = "mediacloth"
    s.has_rdoc          = true
    s.extra_rdoc_files  = ["README"]
    s.rdoc_options      << '--title' << 'MediaCloth' << '--main' << 'README'
end