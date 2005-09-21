#!/usr/bin/env ruby

require 'set'

raise 'Current directory must be _darcs' unless File.basename(Dir.pwd) == '_darcs'
log_paths = [ 'inventory', File.join('inventories', '*') ]


@authors = Set.new
@log_text = String.new

# Inventory lines
InventoryReplacePatterns = {
                             /^Starting with tag:$/ => '',
                             /^\[/                  => '', # Start of patch
                           }
AuthorSub = [ /^([^*]+)\*\*\d+(\] )?/, '\1' ]


def process_path(path)
  File.open path do |f|
    author_next = false

    f.each do |line|
      new_line = line.chomp

      if author_next
        author_next = false
        md = new_line.match(/^([^*]+)\*\*\d+(\] )?(.*)/)
        author, new_line = md[1], md[-1]
        @authors << author
      end

      author_next = true if new_line[0] == ?[

      InventoryReplacePatterns.each do |patt,repl|
        new_line.sub! patt, repl
      end

      @log_text << new_line << "\n" unless new_line == '' || new_line == '] '
    end
  end
end


log_paths.each do |p|
  curr_path = File.join(Dir.pwd, p)
  if File.file? curr_path
    process_path curr_path
  else
    Dir.glob(curr_path).each {|path| process_path path }
  end
end

puts "Authors: #{@authors.to_a.join ', '}"
puts @log_text
