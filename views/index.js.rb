class Index < React
  def initialize
    @messages = []
  end

  def render
    _table do
      _thead do
	_tr do
	  _th 'Timestamp'
	  _th 'From'
	  _th 'Subject'
	end
      end

      _tbody do
	@messages.each do |messsage|
	  _tr do
	    _td do
	      _a messsage.time, href: "#{messsage.href}"
	    end 
	    _td messsage.from
	    _td messsage.subject
	  end
	end
      end
    end

    _input.btn.btn_primary type: 'submit', value: 'fetch previous month',
      onClick: self.fetch
  end

  def componentWillMount()
    @latest = @@mbox
  end

  def componentDidMount()
    self.fetch()
  end

  def fetch()
    # build JSON post XMLHttpRequest
    xhr = XMLHttpRequest.new()
    xhr.open 'POST', "", true
    xhr.setRequestHeader 'Content-Type', 'application/json;charset=utf-8'
    xhr.responseType = 'json'

    # process response
    def xhr.onreadystatechange()
      if xhr.readyState == 4
	response = xhr.response.json

	# update latest mbox
	@latest = response.mbox if response.mbox

	# add messages to list
	@messages = @messages.concat(*response.messages)
      end
    end

    xhr.send(JSON.stringify mbox: @latest)
  end
end
