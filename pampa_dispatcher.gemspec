Gem::Specification.new do |s|
  s.name        = 'pampa_dispatcher'
  s.version     = '1.1.3'
  s.date        = '2020-01-25'
  s.summary     = "THIS GEM IS STILL IN DEVELOPMENT STAGE. Distribute work along a pool of Pampa workers."
  s.description = "THIS GEM IS STILL IN DEVELOPMENT STAGE. Find documentation here: https://github.com/leandrosardi/pampa_dispatcher."
  s.authors     = ["Leandro Daniel Sardi"]
  s.email       = 'leandro.sardi@expandedventure.com'
  s.files       = [
    "lib/pampa_dispatcher.rb",
  ]
  s.homepage    = 'https://rubygems.org/gems/pampa_dispatcher'
  s.license     = 'MIT'
  s.add_runtime_dependency 'websocket', '~> 1.2.8', '>= 1.2.8'
  s.add_runtime_dependency 'json', '~> 1.8.1', '>= 1.8.1'
  s.add_runtime_dependency 'tiny_tds', '~> 1.0.5', '>= 1.0.5'
  s.add_runtime_dependency 'sequel', '~> 4.28.0', '>= 4.28.0'
  s.add_runtime_dependency 'pampa_workers', '~> 1.1.1', '>= 1.1.1'
end