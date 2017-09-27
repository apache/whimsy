# https://alligator.io/vuejs/global-event-bus/
EventBus = new Vue()

# export 'dollar-less' version of event methods to make them easier to call
%w(emit on once off).each do |method|
  EventBus[method] = EventBus['$' + method]
end
