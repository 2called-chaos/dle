module Dle
  class Filesystem
    class Node
      attr_reader :path, :fs

      def initialize fs, path
        @fs = fs
        @path = path
      end

      def relative_path
        @fs.relative_path(@path)
      end

      def mode
        sprintf("%o", stat.mode).to_s[-3..-1]
      end

      def owngrp
        "#{owner}:#{group}"
      end

      def owner
        Etc.getpwuid(stat.uid).name
      end

      def group
        Etc.getgrgid(stat.gid).name
      end

      def inode
        "#{stat.dev.to_s(36)}-#{stat.ino.to_s(36)}"
      end

      [:basename, :dirname, :extname, :stat, :size].each do |meth|
        define_method(meth) {|*a| File.send(meth, @path, *a) }
      end

      [:directory?, :file?, :symlink?].each do |meth|
        define_method(meth) {|*a| FileTest.send(meth, @path, *a) }
      end
    end
  end
end
