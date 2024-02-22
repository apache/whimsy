--[[
  This is an output filter for HTML files
  It adds a banner when maintenance mode is detected

  It is invoked by the following file exists:
  /srv/whimsy/www/maintenance.txt

  The mod_lua API is described here:
  https://httpd.apache.org/docs/current/mod/mod_lua.html#modifying_buckets

  How it works:
    For simplicity, we add the banner to the start of the page.

    This is not really valid HTML, but seems to work in most cases, and avoids having to find a better
    place to insert it.

]]--

function output_filter(r)
    -- We only filter text/html types
    if not r.content_type:match("text/html") then return end

    -- create the customised banner
    local divstyle = 'font-size:x-large;padding:15px;color:white;background:red;z-index:99;' ;
    local div = ([[
      <div style='%s'>
        The Whimsy server is undergoing maintenance. Not all functions are available.
      </div>]]):format(divstyle)

    -- add header:
    coroutine.yield(div)

    -- spit out the actual page
    while bucket ~= nil do
        coroutine.yield(bucket)
    end

    -- no need to add anything at the end of the content

end
