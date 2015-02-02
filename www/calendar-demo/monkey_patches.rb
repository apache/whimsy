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

# Need to submit pull requests for https://github.com/sstephenson/execjs
Wunderbar.unsafe!

# Proof of concept implementation of React.render method; needs to be
# cleaned up, generalized, and have tests written for it before it can
# be added to Wunderbar proper.
require 'execjs'
require 'nokogumbo'
class Wunderbar::XmlMarkup
  def render element, container, properties={}
    # find and delete the node from the tree
    node = element.node?
    node.parent.children.delete(node)

    # find the root node
    root = node.parent
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

    script = scripts.last
    public_folder = Sinatra::Application.public_folder
    react = File.read("#{public_folder}/#{scripts.first.attrs[:src]}")
    view_folder = Sinatra::Application.views
    script = File.read("#{view_folder}/#{scripts.last.attrs[:src]}.rb")
    context = ExecJS.compile(react + Ruby2JS.convert(script))

    builder = Wunderbar::HtmlMarkup.new({})
    render = builder._ do
      context.eval("React.renderToString(React.createElement(#{node.name}," +
       "#{JSON.generate(properties)}))")
    end
    targets.each do |target|
      target.children += render
    end

    script = tag! 'script', Wunderbar::ScriptNode
    script.block = <<-EOF
      React.render(_#{node.name}(#{properties.inspect}),
        document.getElementById(#{container[1..-1].inspect}))
    EOF
  end
end
