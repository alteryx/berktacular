require 'minitest'
require 'minitest/autorun'
require 'berktacular'
require 'json'
require 'solve'

class BerktacularTest < Minitest::Test
  def setup
    e = "./test/test_env.json"
    unless File.exists?(e)
      puts "Where is e?"
    end
    @env = JSON.parse File.read(e)
  end

  def test_simple_case
    b = 'postgresql'
    c = Berktacular::Cookbook.new(
      b,
      @env['cookbook_versions'][b],
      @env['cookbook_locations'][b]
    )
    assert_equal 'cookbook "postgresql", "3.3.4"', c.to_s
  end
  def test_complex_case
    b = 'lumberjack'
    c = Berktacular::Cookbook.new(
      b,
      @env['cookbook_versions'][b],
      @env['cookbook_locations'][b]
    )
    assert_equal 'cookbook "lumberjack", git: "git@github.com:hectcastro/chef-lumberjack.git", protocol: :ssh, ref: "314a5736f0a7ea044a346463f9a431620dc59f25"', c.to_s
  end
end
