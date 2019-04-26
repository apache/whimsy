require 'json'

run lambda {|env|
  env = env.to_a.sort.to_h
  env.delete('PASSENGER_CONNECT_PASSWORD')
  env.delete('SECRET_KEY_BASE')

  [ 200, {'Content-Type' => 'text/plain'}, [JSON.pretty_generate(env)] ]
}
