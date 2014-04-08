require 'test/unit'
require 'berktacular'

class BerktacularTest < Test::Unit::TestCase
  
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
    @berksfile = Berktacular::Berksfile.new("./test/test_env.json", {token: t} )
    puts "#{@berksfile}"
    @golden = File.read("test/golden.sample")
  end

  def test_can_generate_berksfile
    assert_equal @golden, @berksfile.to_s
  end
end
