# frozen_string_literal: true

module Kiln
  # Finds a Kiln app from a directory and loads its configuration
  module AppLoader
    CONFIG = "config/application.rb"

    def self.find_root(start = Dir.pwd)
      dir = File.expand_path(start)
      loop do
        return dir if File.file?(File.join(dir, CONFIG))

        parent = File.dirname(dir)
        return nil if parent == dir

        dir = parent
      end
    end

    def self.load(start = Dir.pwd)
      root = find_root(start) or raise Error, "not inside a Kiln app (no #{CONFIG} found)"
      require File.join(root, CONFIG)

      real_root = File.realpath(root)
      Application.for_root(real_root) or
        raise Error, "#{CONFIG} must create a Kiln::Application with root: pointing at #{root}"

    end
  end
end
