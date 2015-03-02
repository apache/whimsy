def htmlEscape(string)
  return string.gsub('&', '&amp;').gsub('>', '&gt;').gsub('<', '&lt;')
end
