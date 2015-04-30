on_restart do
  puts 'restarting'
  ::Events.close_all
end

