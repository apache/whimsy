_html do
  _link rel: 'stylesheet', href: "../secmail.css?#{@cssmtime}"

  if @dryrun['exception']

    _h2.bg_danger @dryrun['exception']
    _pre @dryrun['backtrace'].join("\n")

    _script %{
      var message = {status: 'warning'}
      window.parent.frames[0].postMessage(message, '*')
    }
  else

    _h1.bg_warning 'Operations to be performed'
  
    _ul.tasklist! do
      @dryrun['tasklist'].each do |task|
        _li do 
          _h3 task['title']

          task['form'].each do |element|
            element.last[:disabled] = true if Hash === element.last
            tag! *element
          end
        end
      end
    end

    if @dryrun['warn']
      _div.alert.alert_danger do
        _b 'Warning:'
        _span @dryrun['warn']
       end

      _button.btn.btn_danger 'proceed'

      _script %{
        var message = {status: 'warning'}
        window.parent.frames[0].postMessage(message, '*')
      }
    else
      _button.btn.btn_primary 'proceed'
    end

    _script "var params = #{JSON.generate(params)};"

    _script src: "../tasklist.js?#{@jsmtime}"
  end
end
