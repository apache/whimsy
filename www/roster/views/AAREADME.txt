The contents of the views directory *except* for the 
'actions' subdirectory are run on the client.

To factor out code from actions, it needs to be placed
outside of the views directory and 'required' by main.rb.

Files under 'actions' are named *.json.rb
They return a JSON response to the client

Other files are *.js.rb or *.html.eb and are converted to the appropriate
client format -- JavaScript or HTML
