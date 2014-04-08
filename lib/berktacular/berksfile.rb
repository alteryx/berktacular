module Berktacular
  class Berksfile
    attr_reader :name, :description, :installed, :missing_deps
    def initialize( environment, opts = {})
      @env_hash           = environment # Save the whole thing so we can emit an updated version if needed.
      @name               = environment['name']               || nil
      @description        = environment['description']        || nil
      @cookbook_versions  = environment['cookbook_versions']  || {}
      @cookbook_locations = environment['cookbook_locations'] || {}
      @opts = {
        :upgrade => opts.has_key?(:upgrade) ? opts[:upgrade] : false,
        :token   => opts.has_key?(:token)   ? opts[:token]   : nil,
        :verbose => opts.has_key?(:verbose) ? opts[:verbose] : false
      }
      @installed = {}
      # only connect once, pass the client to each cookbook.  and only if needed
      connect_to_git if @opts[:upgrade]
    end

    def env_file
      if @opts[:upgrade]
        cookbooks.each do |book|
          @env_hash['cookbook_versions'][book.name] = book.version_specifier
        end
      end
      @env_hash
    end

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

    def upload(berksrc, kniferc, workdir=nil)
      raise "No berks config, required for upload" unless berksrc && File.exists?(berksrc)
      raise "No knife config, required for upload" unless kniferc && File.exists?(kniferc)
      workdir       = install(workdir)
      new_env_file  = File.write(File.join(workdir, @name + ".rb"), JSON.pretty_generate(env_file))
      Berktacular.run_command("berks upload --berksfile #{@installed[workdir][:berksfile]} --c #{berksrc}")
      Berktacular.run_command("knife environment from file #{new_env_file} -c #{kniferc}")
    end

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

    def print_berksfile( io = STDOUT )
      io.puts to_s  
    end

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

    def cookbooks
      @cookbooks ||= @cookbook_versions.sort.map do |book, version|
        Cookbook.new(book, version, @cookbook_locations[book], @opts ) 
      end
    end

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
    def connect_to_git
      raise "No token given, can't connect to git" unless @opts[:token]
      require 'octokit'
      @opts['git_client'] ||= Octokit::Client.new(access_token: @opts[:token])      
    end

  end
end
