# Filter out "data property already declared as a prop" warnings
Vue.config.warnHandler = proc do |msg, vm, trace|
  return if msg =~ /^The data property "\w+" is already declared as a prop\./
  console.error "[Vue warn]: " + msg + trace if defined? console
end

# reraise uncapturable errors asynchronously to enable easier debugging
Vue.config.errorHandler = proc do |err, vm, info|
  setTimeout(0) { raise err }
end
