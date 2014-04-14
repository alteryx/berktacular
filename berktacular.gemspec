lib = File.expand_path('../lib/', __FILE__)
$:.unshift lib unless $:.include?(lib)
require 'berktacular/version'

spec = Gem::Specification.new do |s|
  s.name        = 'berktacular'
  s.version     = Berktacular::VERSION
  s.date        = Time.now.strftime('%Y-%m-%d')
  s.summary     = 'Parse chef env files, generates a Berksfile and verifies it.'
  s.description = "Generates a Berksfile from JSON style Chef environment files.  Also support extension to environment file with 'cookbook_locations'. " +
                  "Verifies the Berksfile is consistent (all dependencies met) and will upload updated cookbooks and env files to a chef server."
  s.authors     = ['Jeff Harvey-Smith']
  s.email       = ['jeff@clearstorydata.com']

  s.required_ruby_version = '>= 1.9'

  s.add_dependency 'solve',   '~> 0.8', '>= 0.8.2'
  s.add_dependency 'ridley',  '~> 1.5', '>= 1.5.3'
  s.add_dependency 'octokit', '~> 3.0', '>= 3.0.0'

  s.files       = Dir["{bin,lib}/**/*"]
  s.executables << 'berktacular'
  s.homepage    = 'https://rubygems.org/gems/berktacular'
  s.licenses    = ['Apache License, Version 2.0']
end
