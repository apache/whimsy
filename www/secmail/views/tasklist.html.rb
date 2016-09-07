_html do

  if @dryrun['exception']

    _h2.bg_danger @dryrun['exception']
    _pre @dryrun['backtrace'].join("\n")

  else

    _h1.bg_warning 'Operations to be performed'

    _ul do
      @dryrun['tasklist'].each do |task|
        _li {_h3 task}
      end
    end

    _button.btn.btn_primary 'proceed'

  end
end
