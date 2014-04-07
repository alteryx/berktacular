module Berktacular
    class Cookbook
    attr_reader :name, :version_number, :auto_upgrade, :config
    def initialize( name, version_spec, config = nil, opts = {} )
      @name             = name          || raise( "Missing cookbook name" )
      @version_spec     = version_spec  || raise( "Missing cookbook version" )
      @version_number   = VERSION_RE.match( version_spec )[0]
      @version_solved   = Solve::Version.new(@version_number)
      @auto_upgrade     = config && config['auto_upgrade']  || false
      @versions         = config && config['versions']      || {}
      @config           = config ? config.reject{ |k,v| k == 'auto_upgrade' || k == 'versions' } : nil
      @upgrade          = opts.has_key?('upgrade')      ? opts['upgrade']         : false
      @git_client       = opts.has_key?('git_client')   ? opts['git_client'].dup  : nil
      @verbose          = opts.has_key?('verbose')      ? opts['verbose']         : false
      check_updates if @auto_upgrade && @upgrade
    end

    def version_specifier
      "= #{(@auto_upgrade && @upgrade && check_updates.any?) ? check_updates.first : @version_number }"
    end

    def latest_version
      check_updates.any? ? check_updates.first : @version_number
    end

    def to_s
      line
    end

    def line(upgrade = @upgrade)
      "cookbook \"#{@name}\", #{generate_conf_line(upgrade, @config )}"
    end

    def check_updates
      @candidates ||= if @config && @config['github']
        get_tags_from_github
      else
        []
      end.select do |tag|
        next if @config.has_key?('rel') && ! /^#{@name}-[v\d]/.match(tag)
        m = VERSION_RE.match(tag)
        next unless m
        v = m[0]
        begin
          t = Solve::Version.new(v)
        rescue Solve::Errors::InvalidVersionFormat
          next
        end
        t > @version_solved
      end.sort.reverse
    end

    private

    def generate_conf_line(upgrade, config)
      ver = (upgrade && @candidates && @candiates.first) || @version_number
      line = []
      if config
        if config.has_key?('github')
          line << "github: \"#{config['github']}\""
          line << "rel: \"#{config['rel']}\"" if config.has_key?('rel')
          line << 'protocol: :ssh'
        end
        if @versions.has_key?(ver)
          line << "ref: \"#{@versions[ver]['ref']}\""
        else
          if !@config.has_key?('tag')
            line << "tag: \"#{ver}\""
          else
            line << "tag: \"#{@config['tag']}\""
          end
        end
      else
        line << " \"#{ver}\""
      end
      line.join(", ").gsub('%{version}', ver)
    end

    def get_tags_from_github
      @git_client.repo(@config['github']).rels[:tags].get.data.map { |obj| obj.name }
    end

  end
end
