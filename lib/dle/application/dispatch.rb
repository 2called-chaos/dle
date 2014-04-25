module Dle
  class Application
    module Dispatch
      def dispatch action = (@opts[:dispatch] || :help)
        case action
          when :version, :info then dispatch_info
          else
            if respond_to?("dispatch_#{action}")
              send("dispatch_#{action}")
            else
              abort("unknown action #{action}", 1)
            end
        end
      end

      def dispatch_help
        @optparse.to_s.split("\n").each(&method(:log))
        log ""
        log "To set your favorite editor set the env variable #{c "DLE_EDITOR", :magenta}"
        log "Note that you need a blocking call (e.g. subl -w, mate -w)"
        log "Your current editor is: #{c @editor || "none", :magenta}"
      end

      def dispatch_info
        logger.log_without_timestr do
          log ""
          log "     Your version: #{your_version = Gem::Version.new(Dle::VERSION)}"

          # get current version
          logger.log_with_print do
            log "  Current version: "
            if @opts[:check_for_updates]
              require "net/http"
              log c("checking...", :blue)

              begin
                current_version = Gem::Version.new Net::HTTP.get_response(URI.parse(Dle::UPDATE_URL)).body.strip

                if current_version > your_version
                  status = c("#{current_version} (consider update)", :red)
                elsif current_version < your_version
                  status = c("#{current_version} (ahead, beta)", :green)
                else
                  status = c("#{current_version} (up2date)", :green)
                end
              rescue
                status = c("failed (#{$!.message})", :red)
              end

              logger.raw "#{"\b" * 11}#{" " * 11}#{"\b" * 11}", :print # reset cursor
              log status
            else
              log c("check disabled", :red)
            end
          end
          log "  Selected editor: #{c @editor || "none", :magenta}"

          # more info
          log ""
          log "  DLE DirectoryListEdit is brought to you by #{c "bmonkeys.net", :green}"
          log "  Contribute @ #{c "github.com/2called-chaos/dle", :cyan}"
          log "  Eat bananas every day!"
          log ""
        end
      end

      def dispatch_index
        # require base directory
        base_dir = ARGV[0].present? ? File.expand_path(ARGV[0].to_s) : ARGV[0].to_s
        if !FileTest.directory?(base_dir)
          if base_dir.present?
            abort c(ARGV[0].to_s, :magenta) << c(" is not a valid directory!", :red), 1
          else
            dispatch(:help)
            abort "Please provide a base directory.", 1
          end
        end

        # index filesystem
        log("index #{c base_dir, :magenta}")
        logger.ensure_prefix c("[index]\t", :magenta) do
          @fs = Filesystem.new(base_dir, dotfiles: @opts[:dotfiles])

          # notifier
          if BASH_ENABLED
            notifier = Thread.new do
              loop do
                logger.raw("\033]0;#{@fs.index.count} nodes indexed\007", :print)
                sleep 1
              end
            end
          end

          # index
          @fs.reindex!

          # kill thread
          notifier.kill if BASH_ENABLED
        end
        abort("Base directory is empty or not readable", 1) if @fs.index.empty?
        log("indexed #{c "#{@fs.index.count} nodes", :magenta}") if @fs.index.count > 1000

        file = "#{Dir.tmpdir}/#{SecureRandom.urlsafe_base64}"
        begin
          # read input file or open editor
          if @opts[:input_file]
            ifile = File.expand_path(@opts[:input_file])
            if FileTest.file?(ifile) && FileTest.readable?(ifile)
              @dlfile = DlFile.parse(ifile)
            else
              abort "Input file not readable: " << c(ifile, :magenta)
            end
          else
            FileUtils.mkdir_p(File.dirname(file)) if !FileTest.exist?(File.dirname(file))
            if !FileTest.exist?(file) || File.read(file).strip.empty?
              File.open(file, "w") {|f| f.write @fs.to_dlfile }
            end
            log "open list for editing..."
            open_editor(file)
            @dlfile = DlFile.parse(file)
          end

          # delta changes
          @delta = @fs.delta(@dlfile)

          # no changes
          if @delta.all?{|_, v| v.empty? }
            abort c("No changes, nothing to do..."), 0
          end

          # review
          if @opts[:review]
            @delta.each do |action, snodes|
              logger.ensure_prefix c("[#{action}]\t", :magenta) do
                snodes.each do |snode|
                  if [:chown, :chmod].include?(action)
                    log(c("#{snode.node.relative_path} ", :blue) << c(snode.is, :red) << c(" » ") << c(snode.should, :green))
                  elsif [:cp, :mv].include?(action)
                    log(c(snode.is, :red) << c(" » ") << c(snode.should, :green))
                  else
                    log(c(snode.is, :red) << " (#{snode.snode.mode})")
                  end
                end
              end
            end

            answer = ask("Do you want to apply these changes? [yes/no/edit]")
            while !["y", "yes", "n", "no", "e", "edit"].include?(answer.downcase)
              answer = ask("Please be explicit, yes/no/edit:")
            end
            raise "retry" if ["e", "edit"].include?(answer.downcase)
            abort("Aborted, nothing changed", 0) if !["y", "yes"].include?(answer.downcase)
          end
        rescue
          $!.message == "retry" ? retry : raise
        end

        # apply changes
        log "#{@opts[:simulate] ? "Simulating" : "Applying"} changes..."
        actions_performed = 0
        begin
          @delta.each do |action, snodes|
            logger.ensure_prefix c("[apply-#{action}]\t", :magenta) do
              snodes.each do |snode|
                actions_performed += 1
                Filesystem::Destructive.new(self, action, @fs, snode).perform
              end
            end
          end
        ensure
          log "#{@opts[:simulate] ? "Simulated" : "Peformed"} #{actions_performed} changes..." unless @opts[:simulate]
        end
      end
    end
  end
end
