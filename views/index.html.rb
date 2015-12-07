_html do
  _style %{
    td:nth-child(2), th:nth-child(2) {
      padding-right: 7px;
      padding-left: 7px;
    }
  }

  _table do
    _thead do
      _tr do
        _th 'Timestamp'
        _th 'From'
        _th 'Subject'
      end
    end

    _tbody do
      @messages.each do |id, description|

	# skip if there are no attachments at all
	next unless description[:attachments]

	_tr_ do
	  _td! do
	    _a description[:time], href: "#{description[:source]}/#{id}/"
	  end 
	  _td description[:name]
	  _td description['Subject']
	end
      end
    end
  end

  _input_.btn.btn_primary type: 'submit', value: 'fetch previous month'

  _script do
    # save initial mailbox information
    latest = @mbox

    # handle button clicks
    document.querySelector('.btn').addEventListener('click') do |event|
      # disable button
      event.target.disabled = true

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
          latest = response.mbox if response.mbox

          # add messages to table
          tbody = document.querySelector('tbody')
          response.messages.each do |message|
            # create a table row
            tr = document.createElement 'tr'

            # create a column for the time
            td = document.createElement 'td'
            a = document.createElement 'a'
            a.textContent = message.time
            a.setAttribute 'href', message.href
            td.appendChild a
            tr.appendChild td

            # create a column for the message
            td = document.createElement 'td'
            td.textContent = message.from
            tr.appendChild td

            # create a column for the subject
            td = document.createElement 'td'
            td.textContent = message.subject
            tr.appendChild td

            # append row to table
            tbody.appendChild tr
          end
        end

        # re-enable button
        event.target.disabled = false
      end

      xhr.send(JSON.stringify mbox: latest)
    end
  end
end
