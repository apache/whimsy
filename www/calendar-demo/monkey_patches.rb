# Monkeypatch to address https://github.com/sinatra/sinatra/pull/907
module Rack
  class ShowExceptions
    alias_method :w_pretty, :pretty

    def pretty(*args)
      result = w_pretty(*args)

      unless result.respond_to? :join
        def result.join; self; end
      end

      unless result.respond_to? :each
        def result.each(&block); block.call(self); end 
      end

      result
    end
  end
end

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
require 'nokogumbo'
class Wunderbar::XmlMarkup
  def render container, &block
    csspath = Wunderbar::Node.parse_css_selector(container)

    # find the root node
    root = @node.parent
    root = root.parent while root.parent

    # find the scripts and targets on the page
    scripts = []
    targets = []
    walker = proc do |node|
      if node.name == 'script'
        scripts << node
      elsif node.attrs and "##{node.attrs[:id]}" == container
        targets << node
      elsif node.children
        node.children.each do |child|
          walker[child]
        end
      end
    end
    walker[root]

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

    common = Ruby2JS.convert(block, scope: @_scope)
    server = "React.renderToString(#{common})"
    client = "React.render(#{common}, #{element})"

    public_folder = @_scope.settings.public_folder
    view_folder = @_scope.settings.views
    scripts.map! do |script|
      result = nil
      if script.attrs[:src]
        src = script.attrs[:src]
        if File.exist? "#{public_folder}/#{src}"
          result = File.read("#{public_folder}/#{src}")
        else
          name = File.join(view_folder, src+'.rb')
          result = Ruby2JS.convert(File.read(name)) if File.exist? name
        end
      end

      result
    end

    scripts.compact!
    scripts.unshift 'global=this'
    context = ExecJS.compile(scripts.join(";\n"))

    builder = Wunderbar::HtmlMarkup.new({})
    render = builder._ { context.eval(server) }
    targets.each do |target|
      target.children += render
    end

    tag! 'script', Wunderbar::ScriptNode, client
  end
end

get %r{^/([-\w]+)\.js$} do |script|
  _js :"#{script}"
end
