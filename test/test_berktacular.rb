require 'minitest/autorun'
require 'berktacular'

class BerktacularTest < Minitest::Unit::TestCase
  
  def setup
    g = File.join(ENV['HOME'], '.github-token')
    unless File.exists?(g)
      warn "Testing berktacular requires a github-token at ~/.github-token"
      exit
    end
    t = File.read(g).strip
    e = "./test/test_env.json"
    unless File.exists?(e)
      puts "Where is e?"
    end
    @berksfile = Berktacular::Berksfile.new( JSON.parse(File.read(e)), upgrade: false, token: t )
    puts "#{@berksfile}"
    @golden = File.read("test/golden.sample")
  end

  def test_can_generate_berksfile
    require "pp"
    pp @berksfile
    puts "#{@berksfile}"
    assert_equal "#{@golden}", "#{@berksfile}"
  end
end
