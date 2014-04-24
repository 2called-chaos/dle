module Dle
  class Filesystem
    # This class performs all destructive methods and MUST ENSURE that simulation setting is respected.
    class Destructive
      def initialize app, action, fs, snode
        @app, @action, @fs, @snode = app, action, fs, snode
      end

      def perform
        send("perform_#{@action}")
      end

      def source_node
        @source_node ||= begin
          @fs.reindex!
          @fs.index[@snode.snode.inode]
        end
      end

      def perform_chown
        unam, gnam = @snode.should.split(":")
        uid = Etc.getpwnam(unam).uid
        gid = gnam ? Etc.getgrnam(gnam).gid : Etc.getpwnam(unam).gid
        if @app.opts[:simulate]
          @app.log "File.chown(#{uid}, #{gid}, #{source_node.path})"
        else
          begin
            File.chown(uid, gid, source_node.path)
          rescue Errno::EPERM
            @app.warn "Operation not permitted - #{source_node.path}"
          rescue
            @app.warn "Unhandled error - #{$!.message}"
          end
        end
      end

      def perform_chmod
        if @app.opts[:simulate]
          @app.log "File.chmod(0#{@snode.should}, #{source_node.path})"
        else
          begin
            File.chmod(@snode.should.to_i(8), source_node.path)
          rescue Errno::EPERM
            @app.warn "Operation not permitted - #{source_node.path}"
          rescue
            @app.warn "Unhandled error - #{$!.message}"
          end
        end
      end

      def perform_mv action = :mv
        dest = File.expand_path(@snode.snode.path)
        dest_dir = File.dirname(dest)

        # ensure destination directory
        if !FileTest.directory?(dest_dir)
          if @app.opts[:simulate]
            @app.log "FileUtils.mkdir_p(#{dest_dir})"
          else
            begin
              FileUtils.mkdir_p(dest_dir)
            rescue Errno::EPERM
              @app.warn "Operation not permitted - #{dest_dir}"
            rescue
              @app.warn "Unhandled error - #{$!.message}"
            end
          end
        end

        # use recursive copy for directories
        action = :cp_r if action == :cp && FileTest.directory?(source_node.path)

        if @app.opts[:simulate]
          @app.log "FileUtils.#{action}(#{source_node.path}, #{dest})"
        else
          begin
            FileUtils.send(action, source_node.path, dest)
          rescue Errno::EPERM
            @app.warn "Operation not permitted - #{source_node.path} => #{dest}"
          rescue
            @app.warn "Unhandled error - #{$!.message}"
          end
        end
      end

      def perform_cp
        perform_mv :cp
      end

      def perform_rm
        case @snode.snode.mode
          when "del" then _perform_rm
          when "delf" then _perform_rm(:rm_f)
          when "delr" then _perform_rm(:rm_r)
          when "delrf" then _perform_rm(:rm_rf)
          else raise(RuntimeError, "unknown rm mode #{@snode.snode.mode}")
        end
      end

      def _perform_rm action = :rm
        if @app.opts[:simulate]
          @app.log "FileUtils.#{action}(#{source_node.path})"
        else
          begin
            FileUtils.send(action, source_node.path)
          rescue Errno::EPERM
            @app.warn "Operation not permitted - #{source_node.path}"
          rescue
            @app.warn "Unhandled error - #{$!.message}"
          end
        end
      end
    end
  end
end
