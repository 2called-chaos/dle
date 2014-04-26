# DLE

**Directory List Edit – Edit file structures in your favorite editor!**
You can copy, move, rename, chmod, chown or remove individual files or directories with your favorite text editor.

**BETA product, use at your own risk, use `--simulate` to be sure, always have a backup!**

**[» See it in action!](https://www.youtube.com/watch?v=-xfnx3VQvNQ)**

## Requirements

You will need a UNIX system with a working Ruby installation, sorry Windozer!

## Installation

Simple as:

    $ gem install dle

You may also want to define your favorite editor by setting this enviromental variable (in your profile or bashrc):

    export DLE_EDITOR="subl -w"

Note that you need a blocking call to the editor (for GUI editors). Sublime and Textmate both accept `-w` or `--wait`.

## Usage

To get a list of available options invoke DLE with the `--help` or `-h` option:

    Usage: dle [options] base_directory
        -d, --dotfiles                   Include dotfiles (unix invisible)
        -r, --skip-review                Skip review changes before applying
        -s, --simulate                   Don't apply changes, show commands instead
        -f, --file DLFILE                Use input file (be careful)
        -o, --only pattern               files, dirs or regexp (without delimiters)
                                           e.g.: dle ~/Movies -o "(mov|mkv|avi)$"
        -m, --monochrome                 Don't colorize output
        -h, --help                       Shows this help
        -v, --version                    Shows version and other info
        -z                               Do not check for updates on GitHub (with -v/--version)

Change into a directory you want to work with and invoke DLE:

    dle .
    dle ~/some_path

Your editor will open with a list of your directory structure which you can edit accordingly to these rules:

  * If you remove a line we just don't care!
  * If you add a line we just don't care!
  * If you change a path we will "mkdir -p" the destination and move the file/dir
  * If you change the owner we will "chown" the file/dir
  * If you change the mode we will "chmod" the file/dir
  * If you change the mode to "cp" and modify the path we will copy instead of moving/renaming
  * If you change the mode to "del" we will "rm" the file
  * If you change the mode to "delr" we will "rm" the file or directory
  * If you change the mode to "delf" or "delrf" we will "rm -f" the file or directory
  * We will apply changes in this order (inside-out):
    * Ownership
    * Permissions
    * Rename/Move
    * Copy
    * Delete

## Caveats

DLE relies on inode values, do not use with hardlinks! This may lead to unexpected file operations or data loss!

## Contributing

1. Fork it ( http://github.com/2called-chaos/dle/fork )
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request
