module Dle
  class DlFile
    def self.generate fs
      Generator.new(fs).render
    end

    def self.parse file
      Parser.new(file).parse
    end

    class Parser
      def initialize file
        @file = file
      end

      def parse
        {}.tap do |fs|
          return fs unless File.readable?(@file)
          File.readlines(@file).each do |l|
            next if l.start_with?("#")
            if l.strip.start_with?("<HD-BASE>")
              fs[:HD_BASE] = l.strip.gsub("<HD-BASE>", "").gsub("</HD-BASE>", "")
            elsif l.strip.start_with?()
              fs[:HD_DOTFILES] = l.strip.gsub("<HD-DOTFILES>", "").gsub("</HD-DOTFILES>", "") == "true"
            elsif l.count("|") >= 4
              # parse line
              chunks = l.split("|")
              data = {}.tap do |r|
                r[:inode] = chunks.shift.strip
                r[:mode] = chunks.shift.strip
                r[:uid], r[:gid] = chunks.shift.split(":").map(&:strip)
                chunks.shift # ignore size
                r[:relative_path] = chunks.join("|").strip
                r[:path] = [fs[:HD_BASE], r[:relative_path]].join("/")
              end

              # skip headers
              next if data[:inode].downcase == "in"
              next if data[:mode].downcase == "mode"
              next if data[:uid].downcase == "owner"
              next if data[:relative_path].downcase == "file"

              # map node
              if fs.key? data[:inode]
                Thread.main.app_logger.warn "inode #{data[:inode]} already mapped, ignore..."
              else
                fs[data[:inode]] = Filesystem::Softnode.new(data)
              end
            end
          end
          Thread.main.app_logger.warn("DLFILE has no HD-BASE, deltaFS will fail!") unless fs[:HD_BASE].present?
        end
      end
    end

    class Generator
      include Helpers

      def initialize fs
        @fs = fs
      end

      def render
        # inode, mode, own/grp, size, file
        table = [[], [], [], [], []]
        @fs.index.each do |rpath, node|
          table[0] << node.inode
          table[1] << node.mode
          table[2] << node.owngrp
          table[3] << human_filesize(node.size)
          table[4] << node.relative_path
        end

        ([
          %{#},
          %{# - If you remove a line we just don't care!},
          %{# - If you add a line we just don't care!},
          %{# - If you change a path we will "mkdir -p" the destination and move the file/dir},
          %{# - If you change the owner we will "chown" the file/dir},
          %{# - If you change the mode we will "chmod" the file/dir},
          %{# - If you change the mode to "cp" and modify the path we will copy instead of moving/renaming},
          %{# - If you change the mode to "del" we will "rm" the file},
          %{# - If you change the mode to "delr" we will "rm" the file or directory},
          %{# - If you change the mode to "delf" or "delrf" we will "rm -f" the file or directory},
          %{# - We will apply changes in this order (inside-out):},
          %{#     - Ownership},
          %{#     - Permissions},
          %{#     - Rename/Move},
          %{#     - Copy},
          %{#     - Delete},
          %{#},
          %{# Gotchas:},
          %{#   - If you have "folder/subfolder/file" and want to rename "subfolder" to "dubfolder"},
          %{#     do it only in the specific node, don't change the path of "file"!},
          %{#   - If you want to copy a directory, only copy the directory node, not a file inside it.},
          %{#     Folders will be copied recursively.},
          %{#   - The script works with file IDs (IN column). That allows you to remove files in renamed},
          %{#     folders without adjusting paths. This is not a gotcha, it's a hint :)},
          %{#   - Note that indexing is quite fast but applying changes on a base directory with a lot},
          %{#     of files and directories may be slow since we fully reindex after each operation.},
          %{#     Maybe the mapping will keep track of changes in later updates so that this isn't necessary},
          %{# --------------------------------------------------},
          %{},
          %{<HD-BASE>#{@fs.base_dir}</HD-BASE>},
          %{<HD-DOTFILES>#{@fs.opts[:dotfiles]}</HD-DOTFILES>},
          %{},
        ] + render_table(table, ["IN", "Mode", "Owner", "Size", "File"])).map(&:strip).join("\n")
      end
    end
  end
end
