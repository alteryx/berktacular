require 'semverse'
require 'ridley'

module Berktacular

  # This class represents a cookbook entry from a Berksfile

  class Cookbook

    # @!attribute [r] name
    #   @return [String] the name of the cookbook.
    # @!attribute [r] version_number
    #   @return [String] the exact version of the cookbook.
    # @!attribute [r] auto_upgrade
    #   @return [True, False] whether or now this cookbook can autoupgrade.
    # @!attribute [r] config
    #   @return [Hash, nil] the cookbook_location hash associated with this cookbook or nil
    attr_reader :name, :version_number, :auto_upgrade, :config

    # Creates a new cookbook entry for a Berksfile.
    #
    # @param name [String] the name of the cookbook to use.
    # @param version_spec [String] the exact version number as in a chef environment file. eg. '= 1.2.3'
    # @param config [Hash,nil] the cookbook_location hash to for this cookbook.  Optional.
    # @option opts [Octokit::Client] :git_client (nil) the github client to use.
    # @option opts [True,False] :upgrade (False) whether or not to check for updates.  auto_upgrade must also be enabled for the updated entry to be used.
    # @option opts [True,False] :verbose (False) be more verbose.
    def initialize( name, version_spec, config = nil, opts = {} )
      @name             = name          || raise( "Missing cookbook name" )
      @version_spec     = version_spec  || raise( "Missing cookbook version" )
      @version_number   = VERSION_RE.match( version_spec )[0]
      @version_solved   = Semverse::Version.new(@version_number)
      @auto_upgrade     = config && config['auto_upgrade']  || false
      @versions         = config && config['versions']      || {}
      @location         = config ? config.reject{ |k,v| k == 'auto_upgrade' || k == 'versions' } : nil
      @version_only     = opts.has_key?(:versions_only) ? opts[:versions_only]  : false
      @upgrade          = opts.has_key?(:upgrade)      ? opts[:upgrade]         : false
      @git_client       = opts.has_key?(:git_client)   ? opts[:git_client].dup  : nil
      @verbose          = opts.has_key?(:verbose)      ? opts[:verbose]         : false
      @multi_cookbook_dir = opts[:multi_cookbook_dir]
      check_updates if @auto_upgrade && @upgrade
    end

    # @return [String] the exact version of the cookbook
    def version_specifier
      "= #{(@auto_upgrade && @upgrade && check_updates.any?) ? check_updates.first : @version_number }"
    end

    # @return [String] the latest available version number of the cookbook
    def latest_version
      check_updates.any? ? check_updates.first : @version_number
    end

    # @return [String] a Berksfile line for this cookbook
    def to_s
      line
    end

    # param upgrade [True,False] ('@upgrade') whether or not to force the lastest version when @auto_update is enabled
    # @return [String] a Berksfile line for this cookbook
    def line(upgrade = @upgrade)
      "cookbook \"#{@name}\", #{generate_conf_line(upgrade, @location )}"
    end

    # @return [Array] a list of available cookbook version newer then we started with, with most recent first
    def check_updates
      tag_re = Regexp.new(
        "^#{ (@location || {})['tag'] || '%{version}' }$" % { :version => "(#{VERSION_RE.source})" }
      )
      @candidates ||= if @location && @location['github']
        get_tags_from_github
      else
        []
      end.collect do |tag|
        m = tag_re.match(tag)
        next unless m
        v = m[1]
        begin
          t = Semverse::Version.new(v)
        rescue Semverse::InvalidVersionFormat
          next
        end
        next unless t > @version_solved
        t.to_s
      end.compact.sort.reverse
    end

    private

    # @param upgrade [True,False] use updated cookbook version if @auto_update is also true.
    # @param config [Hash] the cookbook_locations hash associated with this cookbook.
    # @return [String] the config line for this cookbook, everything after the cookbook name.
    def generate_conf_line(upgrade, config)
      ver = (upgrade && @candidates && @candidates.first) || @version_number
      line = []
      if config && ! @version_only
        # Allow using coobkooks residing in subdirectories of a "multi-cookbook directory"
        # (this can be e.g. the Chef repository) if the version matches.
        if config.has_key?('rel') && @multi_cookbook_dir
          local_cookbook_dir = File.join(@multi_cookbook_dir, config['rel'])
          if Dir.exists?(local_cookbook_dir)
            metadata_path = Dir["#{File.join(local_cookbook_dir, 'metadata')}.{rb,json}"].first
            if metadata_path
              metadata = Ridley::Chef::Cookbook::Metadata.from_file(metadata_path)
              if metadata.version == ver
                line << "path: \"#{local_cookbook_dir}\""
                return line.join(', ')
              end
            end
          end
        end

        if config.has_key?('github')
          line << "git: \"git@github.com:#{config['github']}.git\""
          line << "rel: \"#{config['rel']}\"" if config.has_key?('rel')
          line << 'protocol: :ssh'
        end
        if @versions.has_key?(ver)
          line << "ref: \"#{@versions[ver]['ref']}\""
        else
          if !@location.has_key?('tag')
            line << "tag: \"#{ver}\""
          else
            line << "tag: \"#{@location['tag']}\""
          end
        end
      else
        line << "\"#{ver}\""
      end
      line.join(", ").gsub('%{version}', ver)
    end

    # return [Array] a list of tags from the github repository of this cookbook.
    def get_tags_from_github
      @@tags_cache ||= {}
      repo_path = @location['github']
      return @@tags_cache[repo_path] if @@tags_cache[repo_path]
      tags = @git_client.tags(@location['github']).map { |obj| obj.name }
      @@tags_cache[repo_path] = tags
      tags
    end

  end
end
