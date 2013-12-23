require 'mail'

Mail.defaults do
  delivery_method :test

  @from = 'Unit Test <unittest@apache.org>'
  @sig = %{
    -- Unit Test
    Secretary Workbench, Apache Software Foundation
  }
end
