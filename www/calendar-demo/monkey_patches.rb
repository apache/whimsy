# Monkeypatch to address https://github.com/sstephenson/execjs/pull/180
require 'execjs'
class ExecJS::ExternalRuntime::Context
  alias_method :w_write_to_tempfile, :write_to_tempfile
  def write_to_tempfile(*args)
    tmpfile = w_write_to_tempfile(*args).path.untaint
    tmpfile = Struct.new(:path, :to_str).new(tmpfile, tmpfile)
    def tmpfile.unlink
      File.unlink path
    end
    tmpfile
  end
end

# Proof of concept implementation of React.render method; needs to be
# cleaned up, generalized, and have tests written for it before it can
# be added to Wunderbar proper.
Wunderbar::CALLERS_TO_IGNORE.clear
require 'nokogumbo'
class Wunderbar::XmlMarkup
  def render container, &block
    csspath = Wunderbar::Node.parse_css_selector(container)
    root = @node.root

    # find the scripts and target on the page
    scripts = root.search('script')
    target = root.at(container)

    # compute client side container
    element = "document.querySelector(#{container.inspect})"
    if csspath.length == 1 and csspath[0].length == 1
      value = csspath[0].values.first
      case csspath[0].keys.first
      when :id
        element = "document.getElementById(#{value.inspect})"
      when :class
        value = value.join(' ')
        element = "document.getElementsByClassName(#{value.inspect})[0]"
      when :name
        element = "document.getElementsByName(#{value.inspect})[0]"
      end
    end

    # build client and server scripts
    common = Ruby2JS.convert(block, scope: @_scope)
    server = "React.renderToString(#{common})"
    client = "React.render(#{common}, #{element})"

    # extract content of scripts
    scripts.map! do |script|
      result = nil
      if script.attrs[:src]
        src = script.attrs[:src]
        name = File.join(@_scope.settings.public_folder, src)
        if File.exist? name
          result = File.read(name)
        else
          name = File.join(@_scope.settings.views, src+'.rb')
          result = Ruby2JS.convert(File.read(name)) if File.exist? name
        end
      end

      result
    end

    # concatenate and execute scripts on server
    scripts.compact!
    scripts.unshift 'global=this'
    context = ExecJS.compile(scripts.join(";\n"))

    # insert results into target
    builder = Wunderbar::HtmlMarkup.new({})
    target.children += builder._ { context.eval(server) }

    # add client side script
    tag! 'script', Wunderbar::ScriptNode, client
  end
end

get %r{^/([-\w]+)\.js$} do |script|
  _js :"#{script}"
end
