class Polyfill
  def self.require(names, &block)
    Polyfill.new(names, block)
  end

  def initialize(names, block)
    @count = 0
    @names = names
    @block = block

    if @names.include? 'Promise' and defined? Promise
      self.complete()
    else
      script = document.createElement('script')
      script.src = 'javascript/es6-promise.js'
      script.onload = self.complete.bind(self)
      first = document.getElementsByTagName('script')[0]
      first.parentNode.insertBefore(script, first)
    end

    if @names.include? 'fetch' and defined? fetch
      self.complete()
    else
      script = document.createElement('script')
      script.src = 'javascript/fetch.js'
      script.onload = self.complete.bind(self)
      first = document.getElementsByTagName('script')[0]
      first.parentNode.insertBefore(script, first)
    end
  end

  def complete()
    @count += 1
    if @count == @names.length
      @block.call()
    end
  end
end
