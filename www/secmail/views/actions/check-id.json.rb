# check to see if an id is available

if ASF::Person.new(@id).icla?
  {message: 'userid is already taken'}
else
  {message: ''}
end
