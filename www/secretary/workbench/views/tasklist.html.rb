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

    _header do
      _h1.bg_warning 'Operations to be performed'
    end

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

    if @dryrun['info']
      _div.alert.alert_warning do
        _b 'Note:'
        _span @dryrun['info']
      end
    end

    if @dryrun['warn']
      _div.alert.alert_danger do
        _b 'Warning:'
        warning = @dryrun['warn']
        # Allow for array of lines
        if warning.is_a? Array
          warning.each_with_index do |warn, num|
            _br if num > 0 # separator
            # allow for array of array => anchor
            if warn.is_a? Array
              _a warn[0], href: warn[1]
            else
              _span warn
            end
          end
        else
          _span warning
        end
       end

      _div.buttons do
        _button.btn.btn_danger.proceed! 'proceed anyway'
        _button.btn.btn_warning.cancel! 'cancel'
      end

      _script %{
        var message = {status: 'warning'}
        window.parent.frames[0].postMessage(message, '*')
      }
    else
      _div.buttons do
        _button.btn.btn_primary.proceed! 'proceed'
        _button.btn.btn_warning.cancel! 'cancel'
      end
    end

    _script "var params = #{JSON.generate(params)};"

    _script src: "../tasklist.js?#{@jsmtime}"
  end
end
