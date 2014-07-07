require 'minitest'
require 'minitest/autorun'
require 'berktacular'

class BerktacularTest < Minitest::Test

  def setup
    begin
      t = ENV['GITHUB_TOKEN'] || File.read( File.join(ENV['HOME'], '.github-token') ).strip
    rescue Errno::ENOENT
      warn "Testing berktacular requires a github-token"
      warn "Either export GITHUB_TOKEN or create a ~/.github-token file"
      exit 1
    end
    e = "./test/test_env.json"
    unless File.exists?(e)
      puts "Where is #{e}?"
    end
    @berksfile = Berktacular::Berksfile.new( JSON.parse(File.read(e)), upgrade: false, token: t )
    @golden = File.read("test/golden.sample")
  end

  def test_can_generate_berksfile
    require "pp"
    assert_equal "#{@golden}", "#{@berksfile}"
  end
end
