#!/usr/bin/env ruby

require 'fileutils'
require 'berktacular/version'

# This module contains classes that allow for generating Berksfiles from chef environment files.
module Berktacular
  
  # @param h [Object] does a deep copy of whatever is passed in.
  # @return [Object] a deep copy of the passed in object.
  def self.deep_copy(h)
    Marshal.load(Marshal.dump(h))
  end

  # @param [String] a command to run.
  # @return [True] or raise on failure.
  def self.run_command(cmd)
    puts "Running command: #{cmd}"
    unless system(cmd)
      raise "Command failed with exit code #{$?.exitstatus}: #{cmd}"
    end
  end

  # @return [String] the best tmpdir to use for this machine.  Prefers /dev/shm if available.
  def self.best_temp_dir
    require 'tempfile'
    tmp = if File.directory?("/dev/shm") && File.writable?("/dev/shm")
      '/dev/shm'
    else
      '/tmp'
    end
    pat = [
      Time.now().strftime('%Y_%m_%d-%H.%M.%S_'),
      '_berktacular'
    ]
    Dir.mktmpdir(pat, tmp)
  end

  # Matches the numric version information from a tag.
  VERSION_RE = Regexp.new(/\d+(?:\.\d+)*/)

  autoload  :Cookbook,  'berktacular/cookbook'
  autoload  :Berksfile, 'berktacular/berksfile'

end
