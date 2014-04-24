module Dle
  class Filesystem
    attr_reader :base_dir, :index, :opts

    # ==========
    # = Logger =
    # ==========
    [:log, :warn, :abort, :debug].each do |meth|
      define_method meth, ->(*a, &b) { Thread.main.app_logger.send(meth, *a, &b) }
    end

    def logger
      Thread.main.app_logger
    end

    # Shortcut for logger.colorize
    def c str, color = :yellow
      logger.colorize? ? logger.colorize(str, color) : str
    end

    # ---------

    def initialize base_dir, opts = {}
      raise ArgumentError, "#{base_dir} is not a directory" unless FileTest.directory?(base_dir)
      @base_dir = File.expand_path(base_dir).freeze
      @opts = { dotfiles: true }.merge(opts)
      reindex!
    end

    def reindex!
      @index = {}
      index!
    end

    def index!
      Find.find(@base_dir) do |path|
        if File.basename(path)[0] == ?. && !@opts[:dotfiles]
          Find.prune
        else
          index_node(path)
        end
      end
    end

    def relative_path path
      if path.start_with?(@base_dir)
        p = path[(@base_dir.length+1)..-1]
        p.presence || "."
      else
        path
      end
    end

    def to_dlfile
      DlFile.generate(self)
    end

    def delta dlfile
      abort "cannot delta DLFILE without HD_BASE", 1 unless dlfile[:HD_BASE].present?

      # WARNING: The order of this result hash is important as it defines the order we process things!
      {chown: [], chmod: [], mv: [], cp: [], rm: []}.tap do |r|
        logger.ensure_prefix c("[dFS]\t", :magenta) do
          log "HD-BASE is " << c(dlfile[:HD_BASE], :magenta)
          dlfile.each do |ino, snode|
            next if ino == :HD_BASE || ino == :HD_DOTFILES
            node = @index[ino]
            unless node
              warn("INODE " << c(ino, :magenta) << c(" not found, ignore...", :red))
              next
            end

            # flagged for removal
            if %w[del delr delf delrf].include?(snode.mode)
              r[:rm] << Softnode.new(node: node, snode: snode, is: node.relative_path)
              next
            end

            # mode changed
            if "#{snode.mode}".present? && "#{snode.mode}" != "cp" && "#{node.mode}" != "#{snode.mode}"
              r[:chmod] << Softnode.new(node: node, snode: snode, is: node.mode, should: snode.mode)
            end

            # uid/gid changed
            if "#{node.owngrp}" != "#{snode.uid}:#{snode.gid}"
              r[:chown] << Softnode.new(node: node, snode: snode, is: node.owngrp, should: "#{snode.uid}:#{snode.gid}")
            end

            # path changed
            if "#{node.relative_path}" != "#{snode.relative_path}"
              r[snode.mode == "cp" ? :cp : :mv] << Softnode.new(node: node, snode: snode, is: node.relative_path, should: snode.relative_path)
            end
          end
        end

        # sort results to perform actions inside-out
        r.each do |k, v|
          r[k] = v.sort_by{|snode| snode.node.relative_path.length }.reverse
        end
      end
    end

  protected

    def index_node path
      Node.new(self, path).tap{|node| @index[node.inode] = node }
    end
  end
end
