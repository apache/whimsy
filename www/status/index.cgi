#!/usr/bin/ruby
require 'wunderbar'

# the following is what infrastructure team sees:
print "Status: 200 OK\r\n\r\n"

# For human consumption:
print <<-EOF
<!DOCTYPE html>
<html>
  <head>
    <meta charset="UTF-8"/>
    <title>Whimsy status</title>
    
    <link rel="stylesheet" type="text/css" href="css/bootstrap.min.css"/>
    <link rel="stylesheet" type="text/css" href="css/status.css"/>
    
    <script type="text/javascript" src="js/jquery.min.js"></script>
    <script type="text/javascript" src="js/bootstrap.min.js"></script>
    <script type="text/javascript" src="js/status.js"></script>
  </head>

  <body>
    <div class="just-padding">
      <div class="list-group list-group-root well">
        Loading...
      </div>
    </div>
  </body>
</html>
EOF
