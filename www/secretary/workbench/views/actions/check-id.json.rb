# check to see if an id is available

if ASF::ICLA.taken?(@id) or ASF::Mail.taken?(@id)
  {message: 'userid is already taken'}
else
  {message: ''}
end
