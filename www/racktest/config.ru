require 'json'

run lambda {|env|
  env = env.to_a.sort.to_h
  env.delete('PASSENGER_CONNECT_PASSWORD')
  env.delete('SECRET_KEY_BASE')
  env.delete('HTTP_AUTHORIZATION')

  begin

    data = {
      id: `id`,
      ruby: RbConfig.ruby,
      ruby_version: RUBY_VERSION,
      gem_version: Gem::VERSION,
      env: env
    }
  
    [ 200, {'Content-Type' => 'text/plain'}, [JSON.pretty_generate(data)] ]
  rescue => e
    [ 500, {'Content-Type' => 'text/plain'}, [e.to_s] ]
  end
}
