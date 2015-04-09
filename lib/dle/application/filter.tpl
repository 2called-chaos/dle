# TIP: Using vim and want to get rid of this example shit?
#      In nav-mode type: 100dd

# Hey there,
# to filter your records you will use Ruby
# but don't be afraid, it's fairly simple.
# Just look at the examples and referenced links.

# Use ruby methods to narrow down you result set.
#   * http://www.ruby-doc.org/core-2.1.1/File.html
#   * http://www.ruby-doc.org/core-2.1.1/Enumerable.html

# ====================================================
# = Doc (remove, reuse or comment out the examples!) =
# ====================================================

puts "Filtering in #{@fs.base_dir}"
@fs.index.select! do |inode, node|
  # node has the following methods
  #   * dir              => source movie directory (e.g. C:/Movies)
  #   * relative_path    => relative path to @fs.base_dir
  #   * mode             => file mode
  #   * owner            => name of the file owner
  #   * group            => name of the file group
  #   * owngrp           => owner and group combined by a colon
  #   * basename         => alias for File#basename
  #   * dirname          => alias for File#dirname
  #   * extname          => alias for File#extname
  #   * stat             => alias for File#stat
  #   * size             => alias for File#size
  #   * directory?       => alias for FileTest#directory?
  #   * file?            => alias for FileTest#file?
  #   * symlink?         => alias for FileTest#symlink?

  # The index is NOT NESTED! If you remove a directory node, all sub nodes
  # will still be in the index!

  # Set break point to interactively call methods from here.
  # See http://pryrepl.org ory type "help" when you are in the REPL.
  # Use exit or exit! to break out of REPL.
  # binding.pry

  # --------------------------------------------------------------

  node.directory? && node.basename =~ /^[a-z0-9]+$/
end

# Filter by name, for regex see http://rubular.com
@fs.index.reject! {|inode, node| node.basename =~ /whatever/i }

# Only big files
@fs.index.select! {|inode, node| node.file? && node.size > 1024 * 1024 * 10 }

# Sort by size
@fs.index.replace Hash[@fs.index.sort_by{|inode, node| node.size }.reverse]
