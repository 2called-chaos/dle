require "pathname"
require "yaml"
require "find"
require "optparse"
require "securerandom"
require "ostruct"
require "tempfile"
begin ; require "pry" ; rescue LoadError ; end

require "active_support/core_ext/object/blank"
require "active_support/core_ext/object/try"

require "banana/logger"
require "dle/version"
require "dle/helpers"
require "dle/dl_file"
require "dle/filesystem/destructive"
require "dle/filesystem/softnode"
require "dle/filesystem/node"
require "dle/filesystem"
require "dle/application/dispatch"
require "dle/application"

module Dle
  ROOT = Pathname.new(File.expand_path("../..", __FILE__))
  BASH_ENABLED = "#{ENV["SHELL"]}".downcase["bash"]
end
