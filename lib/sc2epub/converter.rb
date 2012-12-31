class Sc2epub::Converter
    require 'nkf'
    require 'fileutils'
    require 'cgi'
    require 'pygments'
    
    @@exttable = {
        ".php" => "php",
        ".lua" => "lua",
        ".pl" => "perl",
        ".pm" => "perl",
        ".py" => "python",
        ".rb" => "ruby",
        ".asm" => "nasm",
        ".c" => "c",
        ".h" => "c",
        ".cpp" => "cpp",
        ".c++" => "cpp",
        ".cxx" => "cpp",
        ".hpp" => "cpp",
        ".h++" => "cpp",
        ".hxx" => "cpp",
        ".f" => "fortran",
        ".f90" => "fortran",
        ".go" => "go",
        ".m" => "objective-c",
        ".mm" => "objective-c",
        ".cs" => "csharp",
        ".vb" => "vb.net",
        ".cl" => "common-lisp",
        ".erl" => "erlang",
        ".hs" => "haskell",
        ".groovy" => "groovy",
        ".java" => "java",
        ".scala" => "scala",
        ".sh" => "bash",
        ".bat" => "bat",
        ".ps1" => "powershell",
        ".sql" => "mysql",
        ".yaml" => "yaml",
        ".yml" => "yaml",
        ".as" => "actionscript",
        ".coffee" => "coffee-script",
        ".css" => "css",
        ".html" => "html",
        ".htm" => "html",
        ".xhtml" => "html",
        ".xslt" => "xslt",
        ".json" => "json",
        ".js" => "javascript",
        ".xml" => "xml",
        ".rss" => "xml",
        ".xsl" => "xslt"
    }
    CODES = {
        NKF::JIS      => "JIS",
        NKF::EUC      => "EUC",
        NKF::SJIS     => "SJIS",
        NKF::UTF8     => "UTF8",
        NKF::BINARY   => "BINARY",
        NKF::ASCII    => "ASCII",
        NKF::UNKNOWN  => "UNKNOWN",
    }

    def initialize env, root, output
        @root = path(root)
        @output = output
        @template = Sc2epub::Template::new
        @indexes = []
        @env = env
    end
    def path path
        r = File::expand_path(path)
    end
    def local path
        if path.index(@root)==0
            path = path[@root.size, path.size]
        end
        if path[0,1] == "/"
            path = path[1, path.size]
        end
        return path
    end
    def title path
        path.gsub(/\//, "_").gsub(/\./, '_')
    end
    def dogenerate doctitle
        output = @output
        items = ''; c=0;
        nvitems = ''
        cover = File::join(File::dirname(__FILE__), 'cover.jpg')
        FileUtils::cp(cover, output)
        @indexes.each do |data|
            title = data[:name]
            link = data[:src]
            items += @template.item('id'=>"item#{c+=1}", 'link'=>link)
            nvitems += @template.navi('id'=>"navPoint-#{c}", 'order'=>c.to_s, 'link'=>link, 'title'=>title)
        end
        opf = @template.opf('title'=>doctitle, 'date'=>Time::now.strftime("%Y/%m/%d"),
                            'lang' => @env[:lang],
                            'items'=>items, 'author'=>@env[:author])
        ncx = @template.ncx('title'=>doctitle, 'navitems'=>nvitems)
        opfpath = "#{doctitle}.opf"
        open(File::join(output, opfpath), 'w') do |io|
            io.write(opf)
        end
        open(File::join(output, 'toc.ncx'), 'w') do |io|
            io.write(ncx)
        end
        Dir::mkdir(File::join(output, 'META-INF')) unless FileTest::exists? File::join(output, 'META-INF')
        open(File::join(output, 'META-INF', 'container.xml'), 'w') do |io|
            io.write(@template.container('opfpath'=>opfpath))
        end
        open(File::join(output, 'mimetype'), 'w') do |io|
            io.puts('application/epub+zip')
        end
        makefile = @template.makefile('title'=>doctitle)
        open(File::join(output, 'Makefile'), 'w') do |io|
            io.write(makefile)
        end
    end
    def dofile path
        ext = File::extname(path)
        basename = File::basename(path)
        directoryname = File::dirname(local(path))
        #if ext == '.html' or ext == '.xhtml' or ext == '.jpg' or ext == '.gif' or ext == '.png'
        #    FileUtils::cp(path, @output)
        #    return
        #end
        output = @output
        s = open(path){|io|io.read}
        enc = NKF::guess(s)
        if enc==NKF::BINARY
            return nil
        elsif enc!=NKF::ASCII and enc!=NKF::UTF8
            #p enc
            s = NKF::nkf('-wxm0Lu', s)
        else
            #p 'UTF8?'+CODES[enc]
            s = NKF::nkf('-wxm0Lu', s)
        end
        title = title(local(path))
        
        css = ''
        if @@exttable[ext] == nil
            s = '<pre>'+CGI::escapeHTML(s)+'</pre>'
        else
            s_back = Pygments.highlight(s, :lexer => @@exttable[ext], :options => {:encoding => 'utf-8'})
            if s_back == nil
                p 'ERROR Pygments returns nil'
                p title
                s = '<pre>'+CGI::escapeHTML(s)+'</pre>'
                css = ''
            else
                s = s_back
                css = Pygments.css
            end
        end
        
        if directoryname=='.'
            s = @template.xhtml('title'=>basename, 'body'=>s, 'style'=>css, 'directory'=>'/', 'parentdir'=>'index.html')
        else
            s = @template.xhtml('title'=>basename, 'body'=>s, 'style'=>css, 'directory'=>directoryname, 'parentdir'=>title(directoryname)+'.html')
        end
        npath = title+".html"
        open(File::join(output, npath), "w") do |io|
            io.write(s)
        end
        @indexes << {:src => npath, :name =>local(path), :type => :file}
    end
    def dodir dir
        return [] if File::basename(dir)=~/^\..*/
        direntry = []

        @indexes << {:src => title(local(dir))+'.html', :name => local(dir), :type=>:dir}

        Dir::foreach(dir) do |i|
            next if i=="."||i==".."
            path = File::join(dir, i)
            if FileTest::directory? path
                dodir(path)
                type=:dir
            elsif FileTest::file? path
                dofile(path)
                type=:file
            end
            direntry.push({:name => i, :target => title(local(path))+'.html', :type => type})
        end

        # make DIR.html
        output = @output
        html = ''
        direntry.each do |data|
            title = data[:name]
            link = data[:target]
            if data[:type]==:dir
                title = title + '/'
            end
            html += "<p>" + @template.link('url'=>link, 'title'=>title) + "</p>\n"
        end
        if local(File::dirname(dir)) == ''
            parentdir = 'index.html'
            parentname = '/'
        else
            parentdir = title(local(File::dirname(dir)))+'.html'
            parentname = File::basename(File::dirname(dir))
        end
        html = @template.directory('title'=>File::basename(dir)+'/', 'body'=>html, 'parentdir'=>parentdir, 'parentname'=>parentname)
        open(File::join(output, title(local(dir))+'.html'), 'w') do |io|
            io.write(html)
        end
    end
    def doroot dir
        dir = path(dir)
        root = []

        Dir::foreach(dir) do |i|
            next if i=="."||i==".."
            path = File::join(dir, i)
            if FileTest::directory? path
                dodir(path)
                type=:dir
            elsif FileTest::file? path
                dofile(path)
                type=:file
            end
            root.push({:name => i, :target => title(local(path))+'.html', :type => type})
        end

        # make index.html
        output = @output
        indexhtml = ''
        root.each do |data|
            title = data[:name]
            link = data[:target]
            if data[:type]==:dir
                title = title + '/'
            end
            indexhtml += "<p>" + @template.link('url'=>link, 'title'=>title) + "</p>\n"
        end
        indexhtml = @template.index('title'=>'index', 'body'=>indexhtml)
        open(File::join(output, 'index.html'), 'w') do |io|
            io.write(indexhtml)
        end
    end
end
