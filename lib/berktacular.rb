#!/usr/bin/env ruby

require 'fileutils'
require 'berktacular/version'

module Berktacular
  def self.deep_copy(h)
    Marshal.load(Marshal.dump(h))
  end

  def self.run_command(cmd)
    puts "Running command: #{cmd}"
    unless system(cmd)
      raise "Command failed with exit code #{$?.exitstatus}: #{cmd}"
    end
  end

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

  VERSION_RE = Regexp.new(/\d+(?:\.\d+)*/)

  autoload  :Cookbook,  'berktacular/cookbook'
  autoload  :Berksfile, 'berktacular/berksfile'

end
