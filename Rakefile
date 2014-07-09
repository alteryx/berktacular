$LOAD_PATH.unshift File.expand_path("../lib", __FILE__)

require 'rake/testtask'
require 'yard'
require 'bundler'
require 'bundler/version'
require 'berktacular/version'

Bundler::GemHelper.install_tasks

Rake::TestTask.new do |t|
  t.libs << 'test'
end

YARD::Rake::YardocTask.new do |t|
end

task :build do
  system "gem build berktacular.gemspec"
end

task :release do
  system "gem push berktacular-#{Berktacular::VERSION}.gem"
end

desc "Run tests"
task :default => :test
