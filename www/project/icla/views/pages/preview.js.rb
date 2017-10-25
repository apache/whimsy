class Preview < Vue
  def initialize
    @disabled = false
  end

  def render
    _p 'You are almost done!'

    _p %{
      Please review the following for accuracy, and click submit when
      complete.
    }

    _pre.draft FormData.draft

    _p do
      _button.btn.btn_primary 'Submit', disabled: @disabled,
        onClick: self.submit
    end
  end

  def submit()
    Main.navigate(Complete)
  end
end
