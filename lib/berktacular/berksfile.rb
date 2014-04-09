module Berktacular

  # This class represents a Berksfile

  class Berksfile

    # @!attribute [r] name
    #   @return [String] the name of the environment.
    # @!attribute [r] description
    #   @return [String] a description of the enviroment.
    # @!attribute [r] installed
    #   @return [Hash] a hash of installed cookbook directories.
    # @!attribute [r] missing_deps
    #   @return [Hash] a hash of cookbooks missing dependencies after calling verify.
    attr_reader :name, :description, :installed, :missing_deps

    # Creates a new Berksfile from a chef environment file.
    #
    # @param environment [Hash] a parsed JSON chef environment config.
    # @option opts [String] :github_token (nil) the github token to use.
    # @option opts [True,False] :upgrade (False) whether or not to check for upgraded cookbooks.
    # @option opts [True,False] :verbose (False) be more verbose.
    def initialize( environment, opts = {})
      @env_hash           = environment # Save the whole thing so we can emit an updated version if needed.
      @name               = environment['name']               || nil
      @description        = environment['description']        || nil
      @cookbook_versions  = environment['cookbook_versions']  || {}
      @cookbook_locations = environment['cookbook_locations'] || {}
      @opts = {
        :upgrade => opts.has_key?(:upgrade)       ? opts[:upgrade]      : false,
        :token   => opts.has_key?(:github_token)  ? opts[:github_token] : nil,
        :verbose => opts.has_key?(:verbose)       ? opts[:verbose]      : false
      }
      @installed = {}
      # only connect once, pass the client to each cookbook.  and only if needed
      connect_to_git if @opts[:upgrade]
    end

    # @return [Hash] representation of the env_file.
    def env_file
      if @opts[:upgrade]
        cookbooks.each do |book|
          @env_hash['cookbook_versions'][book.name] = book.version_specifier
        end
      end
      @env_hash
    end

    # @return [String] representation of the env_file in pretty json.
    def env_file_json
      if @opts[:upgrade]
        cookbooks.each do |book|
          @env_hash['cookbook_versions'][book.name] = book.version_specifier
        end
      end
      JSON.pretty_generate(@env_hash)
    end

    # @param workdir [String] the directory in which to install.  If nil, Berktacular.best_temp_dir is used.
    # @return [String] the directory path where the cookbooks were installed.
    def install(workdir = nil)
      if workdir
        FileUtils.mkdir_p(workdir)
      else
        workdir = Berktacular.best_temp_dir
      end
      unless @installed[workdir]
        # remove the Berksfile.lock if it exists (it shouldn't).
        berksfile = File.join(workdir, "Berksfile")
        lck       = berksfile + ".lock"
        FileUtils.rm(lck) if File.exists? lck
        File.write(berksfile, self)
        Berktacular.run_command("berks install --berksfile #{berksfile} --path #{workdir}")
        @installed[workdir] = {berksfile: berksfile, lck: lck}
      end
      workdir
    end

    # @params workdir [String] the directory in which to install.  If nill, Berktacular.best_temp_dir is used.
    # @return [True,False] the status of the verify.
    def verify(workdir = nil)
      require 'ridley'
      @missing_deps = {}
      workdir       = install(workdir)
      versions      = {}
      dependencies  = {}
      Dir["#{workdir}/*"].each do |cookbook_dir|
        next unless File.directory?(cookbook_dir)
        metadata_path   = File.join(cookbook_dir, 'metadata.rb')
        metadata        = Ridley::Chef::Cookbook::Metadata.from_file(metadata_path)
        cookbook_name   = metadata.name
        name_from_path  = File.basename(cookbook_dir)
        unless cookbook_name == name_from_path
          if cookbook_name.empty?
            puts "Cookbook #{name_from_path} has no name specified in metadata.rb"
            cookbook_name = name_from_path
          else
            warn "Cookbook name from metadata.rb does not match the directory name!",
                 "metadata.rb: '#{cookbook_name}'",
                 "cookbook directory name: '#{name_from_path}'"
          end
        end
        versions[cookbook_name] = metadata.version
        dependencies[cookbook_name] = metadata.dependencies
      end
      errors = false
      dependencies.each do |name, deps|
        deps.each do |dep_name, constraint|
          actual_version = versions[dep_name]
          if !actual_version
            @missing_deps[name] = "#{name}-#{versions[name]} depends on #{dep_name} which was not installed!"
            warn @missing_deps[name]
            errors = true
          elsif !Solve::Constraint.new(constraint).satisfies?(actual_version)
            @missing_deps[name] = "#{name}-#{versions[name]} depends on #{dep_name} #{constraint} but #{dep_name} is #{actual_version}!"
            warn @missing_deps[name]
            errors = true
          end
        end
      end
      !errors  
    end

    # @param berks_conf [String] path to the berkshelf config file to use.
    # @param knife_conf [String] path to the knife config file to use.
    # @param workdir [String] Path to use as the working directory.
    #   @default Berktacular.best_temp_dir
    # @return [True] or raise on error.
    def upload(berks_conf, knife_conf, workdir=nil)
      raise "No berks config, required for upload" unless berks_conf && File.exists?(berks_conf)
      raise "No knife config, required for upload" unless knife_conf && File.exists?(knife_conf)
      workdir       = install(workdir)
      new_env_file  = File.write(File.join(workdir, @name + ".rb"), env_file_json )
      Berktacular.run_command("berks upload --berksfile #{@installed[workdir][:berksfile]} --c #{berks_conf}")
      Berktacular.run_command("knife environment from file #{new_env_file} -c #{knife_conf}")
    end

    # param workdir [String,nil] the workdir to remove.  If nil, remove all installed working directories.
    def clean(workdir = nil)
      if workdir
        Fileutils.rm_r(workdir)
        @installed.delete(workdir)
      else
        # clean them all
        @installed.keys.each { |d| FileUtils.rm_r(d) }
        @installed = {}
      end
    end

    # @param [IO] where to write the data.
    def print_berksfile( io = STDOUT )
      io.puts to_s  
    end

    # @return [String] the berksfile as a String object
    def to_s
      str = ''
      str << "# Name: '#{@name}'\n" if @name
      str << "# Description: #{@description}\n\n" if @description
      str << "# This file is auto-generated, changes will be overwritten\n"
      str << "# Modify the .json environment file and regenerate this Berksfile to make changes.\n\n"

      str << "site :opscode\n\n"
      cookbooks.each { |l| str << l.to_s << "\n" }
      str
    end

    # @return [Array] a list of Cookbook objects for this environment.
    def cookbooks
      @cookbooks ||= @cookbook_versions.sort.map do |book, version|
        Cookbook.new(book, version, @cookbook_locations[book], @opts ) 
      end
    end

    # print out the cookbooks that have newer version available on github.
    def check_updates
      connect_to_git
      cookbooks.each do |b|
        candidates = b.check_updates
        next unless candidates.any?
        puts  "Cookbook: #{b.name} (auto upgrade: #{b.auto_upgrade ? 'enabled' : 'disabled'})",
              "\tCurrent:#{b.version_number}",
              "\tUpdates: #{candidates.join(", ")}"
      end
    end

    private

    # connect to github using the token in @opts[:github_token].
    # @return [Octokit::Client] a connected github client.
    def connect_to_git
      raise "No token given, can't connect to git" unless @opts[:github_token]
      require 'octokit'
      @opts['git_client'] ||= Octokit::Client.new(access_token: @opts[:github_token])      
    end

  end
end
