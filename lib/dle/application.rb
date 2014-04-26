module Dle
  # Logger Singleton
  MAIN_THREAD = ::Thread.main
  def MAIN_THREAD.app_logger
    MAIN_THREAD[:app_logger] ||= Banana::Logger.new
  end

  class Application
    attr_reader :opts
    include Dispatch
    include Helpers

    # =========
    # = Setup =
    # =========
    def self.dispatch *a
      new(*a) do |app|
        app.parse_params
        app.logger
        begin
          app.dispatch
        rescue Interrupt
          app.abort("Interrupted", 1)
        end
      end
    end

    def initialize env, argv
      @env, @argv = env, argv
      @editor = which_editor
      @opts = {
        dispatch: :index,
        dotfiles: false,
        check_for_updates: true,
        review: true,
        simulate: false,
      }
      yield(self)
    end

    def parse_params
      @optparse = OptionParser.new do |opts|
        opts.banner = "Usage: dle [options] base_directory"

        opts.on("-d", "--dotfiles", "Include dotfiles (unix invisible)") { @opts[:dotfiles] = true }
        opts.on("-r", "--skip-review", "Skip review changes before applying") { @opts[:review] = false }
        opts.on("-s", "--simulate", "Don't apply changes, show commands instead") { @opts[:simulate] = true ; @opts[:review] = false }
        opts.on("-f", "--file DLFILE", "Use input file (be careful)") {|f| @opts[:input_file] = f }
        opts.on("-o", "--only pattern", c("files", :blue) << c(", ") << c("dirs", :blue) << c(" or regexp (without delimiters)"), "  e.g.:" << c(%{ dle ~/Movies -o "(mov|mkv|avi)$"}, :blue)) {|p| @opts[:pattern] = p }
        opts.on("-m", "--monochrome", "Don't colorize output") { logger.colorize = false }
        opts.on("-h", "--help", "Shows this help") { @opts[:dispatch] = :help }
        opts.on("-v", "--version", "Shows version and other info") { @opts[:dispatch] = :info }
        opts.on("-z", "Do not check for updates on GitHub (with -v/--version)") { @opts[:check_for_updates] = false }
      end

      begin
        @optparse.parse!(@argv)
      rescue OptionParser::ParseError => e
        abort(e.message)
        dispatch(:help)
        exit 1
      end
    end

    def which_editor
      ENV["DLE_EDITOR"].presence ||
      ENV["EDITOR"].presence ||
      `which nano`.presence.try(:strip) ||
      `which vim`.presence.try(:strip) ||
      `which vi`.presence.try(:strip)
    end

    def open_editor file
      system "#{@editor} #{file}"
    end


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

    def ask question
      logger.log_with_print(false) do
        log c("#{question} ", :blue)
        STDOUT.flush
        STDIN.gets.chomp
      end
    end
  end
end
