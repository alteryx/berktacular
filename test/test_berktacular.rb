require 'minitest'
require 'minitest/autorun'
require 'berktacular'

class BerktacularTest < Minitest::Test

  def setup
    begin
      @token = ENV['GITHUB_TOKEN'] || File.read( File.join(ENV['HOME'], '.github-token') ).strip
    rescue Errno::ENOENT
      warn "Testing berktacular requires a github-token"
      warn "Either export GITHUB_TOKEN or create a ~/.github-token file"
      exit 1
    end
    @golden = File.read("./test/golden.sample")
  end

  def golden(suffix=nil)
    suffix = ".#{suffix}" if suffix
    File.read("./test/golden.sample#{suffix}")
  end

  def render_env_file(envfile)
    raise "Asked to render '#{envfile}' but I can't find it!" unless envfile && File.exists?(envfile)
    Berktacular::Berksfile.new( envfile, upgrade: false, token: @token )
  end

  def test_can_generate_berksfile
    berksfile = render_env_file("./test/test_env.json")
    assert_equal "#{golden}", "#{berksfile}"
  end

  def test_can_generate_recursive_berksfile
    berksfile = render_env_file("./test/test_env_child.json")
    assert_equal "#{golden('recursive')}", "#{berksfile}"
  end

  def test_will_raise_on_infinate_recursion
    assert_raises RuntimeError do
      render_env_file("./test/test_env_self_recurse.json")
    end
  end

end

