#!/usr/bin/env ruby
# -*- mode: ruby; coding: utf-8 -*-
#
# di - a wrapper around GNU diff(1)
#
# Copyright (c) 2008 Akinori MUSHA
#
# All rights reserved.
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions
# are met:
# 1. Redistributions of source code must retain the above copyright
#    notice, this list of conditions and the following disclaimer.
# 2. Redistributions in binary form must reproduce the above copyright
#    notice, this list of conditions and the following disclaimer in the
#    documentation and/or other materials provided with the distribution.
#
# THIS SOFTWARE IS PROVIDED BY THE AUTHOR AND CONTRIBUTORS ``AS IS'' AND
# ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
# IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
# ARE DISCLAIMED.  IN NO EVENT SHALL THE AUTHOR OR CONTRIBUTORS BE LIABLE
# FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
# DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS
# OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
# HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
# LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY
# OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF
# SUCH DAMAGE.
#
# $Id$

MYVERSION = "0.1.0"
MYREVISION = %w$Rev$[1]
MYDATE = %w$Date$[1]
MYNAME = File.basename($0)

DIFF_CMD = ENV.fetch('DIFF', 'diff')
EMPTYFILE = '/dev/null'

CVS_EXCLUDE_GLOBS = %w(
  RCS SCCS CVS CVS.adm
  RCSLOG cvslog.* tags TAGS
  .make.state .nse_depinfo *~
  \#* .\#* ,* _$*
  *$ *.old *.bak *.BAK
  *.orig *.rej *.del-* *.a
  *.olb *.o *.obj *.so
  *.exe *.Z *.elc *.ln
  core .svn .git .bzr .hg
)

FIGNORE_GLOBS = ENV.fetch('FIGNORE', '').split(':').map { |pat|
  '*' + pat
}

def main(args)
  setup

  parse_args!(args)

  diff_main

  exit $status
end

def warn(*lines)
  lines.each { |line|
    STDERR.puts "#{MYNAME}: #{line}"
  }
end

def setup
  require 'ostruct'
  $diff = OpenStruct.new
  $diff.exclude = []
  $diff.include = []
  $diff.flags = []
end

def parse_args!(args)
  require 'optparse'

  banner = <<-"EOF"
#{MYNAME} - a wrapper around GNU diff(1)
  version #{MYVERSION} [revision #{MYREVISION}] (#{MYDATE})

usage: #{MYNAME} [flags] [files]
  EOF

  opts = OptionParser.new(banner) { |opts|
    miniTrueClass = Class.new
    hash = OptionParser::CompletingHash.new
    hash['-'] = false
    opts.accept(miniTrueClass, hash) {|arg, val| val == nil or val}

    opts.on('--[no-]cvs-exclude',
      '* Include CVS excluded files and directories.') { |val|
      $diff.cvs_exclude = val
    }
    opts.on('--[no-]ignore-cvs-lines',
      '* Do not ignore CVS keyword lines.') { |val|
      $diff.ignore_cvs_lines = val
    }
    opts.on('--[no-]fignore-exclude',
      '* Include FIGNORE files.') { |val|
      $diff.fignore_exclude = val
    }
    opts.on('-R', '--relative[=-]', miniTrueClass,
      '* Use relative path names.') { |val|
      $diff.relative = val
    }
    opts.on('-i', '--ignore-case[=-]', miniTrueClass,
      'Ignore case differences in file contents.') { |val|
      set_flag('-i', val)
    }
    # not supported (yet)
    #opts.on("--[no-]ignore-file-name-case",
    #  "Ignore case when comparing file names.") { |val|
    #  set_flag("--ignore-file-name-case", val)
    #}
    opts.on('-E', '--ignore-tab-expansion[=-]', miniTrueClass,
      'Ignore changes due to tab expansion.') { |val|
      set_flag('-E', val)
    }
    opts.on('-b', '--ignore-space-change[=-]', miniTrueClass,
      'Ignore changes in the amount of white space.') { |val|
      set_flag('-b', val)
    }
    opts.on('-w', '--ignore-all-space[=-]', miniTrueClass,
      'Ignore all white space.') { |val|
      set_flag('-w', val)
    }
    opts.on('-B', '--ignore-blank-lines[=-]', miniTrueClass,
      'Ignore changes whose lines are all blank.') { |val|
      set_flag('-B', val)
    }
    opts.on('-I RE', '--ignore-matching-lines=RE',
      'Ignore changes whose lines all match RE.') { |val|
      set_flag('-I', val)
    }
    opts.on('--[no-]strip-trailing-cr',
      'Strip trailing carriage return on input.') { |val|
      set_flag('--strip-trailing-cr', val)
    }
    opts.on('-a', '--text[=-]', miniTrueClass,
      'Treat all files as text.') { |val|
      set_flag('-a', val)
    }
    opts.on('-c[NUM]', '--context[=NUM]', Integer,
      'Output NUM (default 3) lines of copied context.') { |val|
      $diff.format = ['-C', val ? val.to_s : '3']
    }
    opts.on('-C NUM', Integer,
      'Output NUM lines of copied context.') { |val|
      $diff.format = ['-C', val.to_s]
    }
    opts.on('-u[NUM]', '--unified[=NUM]', Integer,
      'Output NUM (default 3) lines of unified context.') { |val|
      $diff.format = ['-U', val ? val.to_s : '3']
    }
    opts.on('-U NUM', Integer,
      'Output NUM lines of unified context.') { |val|
      $diff.format = ['-U', val.to_s]
    }
    opts.on('-L LABEL', '--label=LABEL',
      'Use LABEL instead of file name.') { |val|
      set_flag('-L', val)
    }
    opts.on('-p', '--show-c-function[=-]', miniTrueClass,
      'Show which C function each change is in.') { |val|
      set_flag('-p', val)
    }
    opts.on('-F RE', '--show-function-line=RE',
      'Show the most recent line matching RE.') { |val|
      set_flag('-F', val)
    }
    opts.on('-q', '--brief[=-]', miniTrueClass,
      'Output only whether files differ.') { |val|
      set_flag('-q', val)
    }
    opts.on('-e', '--ed[=-]', miniTrueClass,
      'Output an ed script.') { |val|
      if val
        $diff.format = ['-e', val]
      end
    }
    opts.on('--normal[=-]', miniTrueClass,
      'Output a normal diff.') { |val|
      if val
        $diff.format = ['--normal', val]
      end
    }
    opts.on('-n', '--rcs[=-]', miniTrueClass,
      'Output an RCS format diff.') { |val|
      if val
        $diff.format = ['-n', val]
      end
    }
    opts.on('-y', '--side-by-side[=-]', miniTrueClass,
      'Output in two columns.') { |val|
      if val
        $diff.format = ['-y', val]
      end
    }
    opts.on('-W NUM', '--width=NUM', Integer,
      'Output at most NUM (default 130) print columns.') { |val|
      set_flag('-W', val.to_s)
    }
    opts.on('--left-column[=-]', miniTrueClass,
      'Output only the left column of common lines.') { |val|
      set_flag('--left-column', val)
    }
    opts.on('--suppress-common-lines[=-]', miniTrueClass,
      'Do not output common lines.') { |val|
      set_flag('--suppress-common-lines', val)
    }
    opts.on('-D NAME', '--ifdef=NAME',
      'Output merged file to show `#ifdef NAME\' diffs.') { |val|
      set_flag('-D', val)
    }
    opts.on('--old-group-format=GFMT',
      'Format old input groups with GFMT.') { |val|
      set_flag('--old-group-format', val)
    }
    opts.on('--new-group-format=GFMT',
      'Format new input groups with GFMT.') { |val|
      set_flag('--new-group-format', val)
    }
    opts.on('--unchanged-group-format=GFMT',
      'Format unchanged input groups with GFMT.') { |val|
      set_flag('--unchanged-group-format', val)
    }
    opts.on('--line-format=LFMT',
      'Format all input lines with LFMT.') { |val|
      set_flag('--line-format', val)
    }
    opts.on('--old-line-format=LFMT',
      'Format old input lines with LFMT.') { |val|
      set_flag('--old-line-format', val)
    }
    opts.on('--new-line-format=LFMT',
      'Format new input lines with LFMT.') { |val|
      set_flag('--new-line-format', val)
    }
    opts.on('--unchanged-line-format=LFMT',
      'Format unchanged input lines with LFMT.') { |val|
      set_flag('--unchanged-line-format', val)
    }
    opts.on('-l', '--paginate[=-]', miniTrueClass,
      'Pass the output through `pr\' to paginate it.') { |val|
      set_flag('-l', val)
    }
    opts.on('-t', '--expand-tabs[=-]', miniTrueClass,
      'Expand tabs to spaces in output.') { |val|
      set_flag('-t', val)
    }
    opts.on('-T', '--initial-tab[=-]', miniTrueClass,
      'Make tabs line up by prepending a tab.') { |val|
      set_flag('-T', '--initial-tab', val)
    }
    opts.on('--tabsize=NUM', Integer,
      'Tab stops are every NUM (default 8) print columns.') { |val|
      set_flag('--tabsize', val.to_s)
    }
    opts.on('-r', '--recursive[=-]', miniTrueClass,
      'Recursively compare any subdirectories found.') { |val|
      set_flag('-r', val)
      $diff.recursive = val
    }
    opts.on('-N', '--[no-]new-file[=-]', miniTrueClass,
      'Treat absent files as empty.') { |val|
      set_flag('-N', val)
      $diff.new_file = val
    }
    opts.on('--unidirectional-new-file[=-]', miniTrueClass,
      'Treat absent first files as empty.') { |val|
      set_flag('--unidirectional-new-file', val)
    }
    opts.on('-s', '--report-identical-files[=-]', miniTrueClass,
      'Report when two files are the same.') { |val|
      set_flag('-s', val)
    }
    opts.on('-x PAT', '--exclude=PAT',
      'Exclude files that match PAT.') { |val|
      $diff.exclude << val
    }
    opts.on('-X FILE', '--exclude-from=FILE',
      'Exclude files that match any pattern in FILE.') { |val|
      if val == '-'
        $diff.exclude.concat(STDIN.read.split(/\n/))
      else
        $diff.exclude.concat(File.read(val).split(/\n/))
      end
    }
    opts.on('--include=PAT',
      'Do not exclude files that match PAT.') { |val|
      $diff.include << val
    }
    opts.on('-S FILE', '--starting-file=FILE',
      'Start with FILE when comparing directories.') { |val|
      set_flag('-S', val)
    }
    opts.on('--from-file=FILE1',
      'Compare FILE1 to all operands.  FILE1 can be a directory.') { |val|
      $diff.from_files = [val]
    }
    opts.on('--to-file=FILE2',
      'Compare all operands to FILE2.  FILE2 can be a directory.') { |val|
      $diff.to_files = [val]
    }
    opts.on('--horizon-lines=NUM', Integer,
      'Keep NUM lines of the common prefix and suffix.') { |val|
      set_flag('--horizon-lines', val.to_s)
    }
    opts.on('-d', '--minimal[=-]', miniTrueClass,
      'Try hard to find a smaller set of changes.') { |val|
      set_flag('-d', val)
    }
    opts.on('--speed-large-files[=-]', miniTrueClass,
      'Assume large files and many scattered small changes.') { |val|
      set_flag('--speed-large-files', val)
    }
    opts.on('-v', '--version',
      'Output version info.') { |val|
      set_flag('-v', val)
    }
    opts.on('--help',
      'Output this help.') { |val|
      print opts,
        "\n",
        "Options without the [*] sign will be passed through to diff(1).\n"
      exit 0
    }
  }

  begin
    opts.parse('--cvs-exclude', '--fignore-exclude', '--ignore-cvs-lines',
               '-N', '-r', '-p', '-d')
    opts.parse!(args)

    $diff.format ||= ['-U', '3']
    set_flag(*$diff.format)

    if $diff.ignore_cvs_lines
      opts.parse('--ignore-matching-lines=\$[A-Z][A-Za-z0-9][A-Za-z0-9]*\(:.*\)\{0,1\}\$')
    end
  rescue OptionParser::ParseError => e
    warn e, "Try `#{MYNAME} --help' for more information."
    exit 64
  rescue => e
    warn e
    exit 1
  end

  begin
    if $diff.from_files
      $diff.to_files ||= args.dup

      if $diff.to_files.empty?
        raise "missing operand"
      end
    elsif $diff.to_files
      $diff.from_files = args.dup

      if $diff.from_files.empty?
        raise "missing operand"
      end
    else
      if args.size < 2
        raise "missing operand"
      end

      if File.directory?(args[0])
        $diff.to_files   = args.dup
        $diff.from_files = [$diff.to_files.shift]
      else
        $diff.from_files = args.dup
        $diff.to_files   = [$diff.from_files.pop]
      end
    end

    if $diff.from_files.size != 1 && $diff.to_files.size != 1
      raise "wrong number of files given"
    end
  rescue => e
    warn e, "Try `#{MYNAME} --help' for more information."
    exit 64
  end
end

def set_flag(flag, val)
  case val
  when false
    $diff.flags.reject! { |f,| f == flag }
  when true
    $diff.flags.reject! { |f,| f == flag }
    $diff.flags << [flag]
  else
    $diff.flags << [flag, val]
  end
end

def diff_main
  $status = 0

  $diff.from_files.each { |from_file|
    if File.directory?(from_file)
      $diff.to_files.each { |to_file|
        if File.directory?(to_file)
          if $diff.relative
            to_file = File.expand_path(from_file, to_file)
          end

          diff_dirs(from_file, to_file)
        else
          if $diff.relative
            from_file = File.expand_path(to_file, from_file)
          else
            from_file = File.expand_path(File.basename(to_file), from_file)
          end

          diff_files(from_file, to_file)
        end
      }
    else
      $diff.to_files.each { |to_file|
        if File.directory?(to_file)
          if $diff.relative
            to_file = File.expand_path(from_file, to_file)
          else
            to_file = File.expand_path(File.basename(from_file), to_file)
          end
        end

        diff_files(from_file, to_file)
      }
    end
  }
end

def diff_files(file1, file2)
  if file1.is_a?(Array)
    file2.is_a?(Array) and raise "cannot compare two sets of multiple files"
    file1.empty? and return 0

    call_diff('--to-file', file2, file1)
  elsif file2.is_a?(Array)
    file1.empty? and return 0

    call_diff('--from-file', file1, file2)
  else
    call_diff(file1, file2)
  end
end

def call_diff(*args)
  system(*[DIFF_CMD, $diff.flags, args].flatten)
  status = $? >> 8
  $status = status if $status < status
  return status
end

def diff_dirs(dir1, dir2)
  entries1 = diff_entries(dir1)
  entries2 = diff_entries(dir2)

  common = entries1 & entries2
  missing1 = entries2 - entries1
  missing2 = entries1 - entries2

  files = []
  common.each { |file|
    file1 = File.join(dir1, file)
    file2 = File.join(dir2, file)
    file1_is_dir = File.directory?(file1)
    file2_is_dir = File.directory?(file2)
    if file1_is_dir && file2_is_dir
      diff_dirs(file1, file2) if $diff.recursive
    elsif !file1_is_dir && !file2_is_dir
      files << file1
    else
      missing1 << file
      missing2 << file
    end
  }
  diff_files(files, dir2)

  [[dir1, missing2], [dir2, missing1]].each { |dir, missing|
    new_files = []
    missing.each { |entry|
      file = File.join(dir, entry)

      if $diff.new_file
        if File.directory?(file)
          if dir.equal?(dir1)
            diff_dirs(file, nil)
          else
            diff_dirs(nil, file)
          end
        else
          new_files << file
        end
      else
        printf "Only in %s: %s (%s)\n",
          dir, entry, File.directory?(file) ? 'directory' : 'file'
        $status = 1 if $status < 1
      end
    }
    if dir.equal?(dir1)
      diff_files(new_files, EMPTYFILE)
    else
      diff_files(EMPTYFILE, new_files)
    end
  }
end

def diff_entries(dir)
  return [] if dir.nil?
  return Dir.entries(dir).reject { |file| diff_exclude?(file) }
rescue => e
  warn "#{dir}: #{e}"
  return []
end

def diff_exclude?(basename)
  return true if basename == '.' || basename == '..'
  return false if $diff.include.any? { |pat|
    File.fnmatch(pat, basename, File::FNM_DOTMATCH)
  }
  return true if $diff.exclude.any? { |pat|
    File.fnmatch(pat, basename, File::FNM_DOTMATCH)
  }
  return true if $diff.cvs_exclude && CVS_EXCLUDE_GLOBS.any? { |pat|
    File.fnmatch(pat, basename, File::FNM_DOTMATCH)
  }
  return true if $diff.fignore_exclude && FIGNORE_GLOBS.any? { |pat|
    File.fnmatch(pat, basename, File::FNM_DOTMATCH)
  }
  return false
end

main(ARGV)
