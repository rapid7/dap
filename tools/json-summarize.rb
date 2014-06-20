#!/usr/bin/env ruby
require 'oj'
require 'optparse'

HELP=<<EOF

 This script is used to locate the frequency of a given key in a json document. It will
 inspect and increment the frequency count for each instance of the key found in the json
 document, then order them in descending order and output a json document with the top n
 occurrences of the key value.

  Note that if passed a key that has unique values, this script can consume a lot of memory.

  Sample:
    unpigz -c /tmp/2014-05-05-mssql-udp-decoded.json.gz | ruby ~/src/dap/tools/json-summarize.rb --top 20 --key data.mssql.Version
EOF

def parse_command_line(args)

  options={
      :key    => nil,
      :number => 100
  }

  OptionParser.new do | opts |
    opts.banner = HELP
    opts.separator ''

    opts.separator 'GeoIP name options:'

    opts.on( '--key keyname', 'The name of json key to be summarized.') do | val |
      options[:key] = val
    end

    opts.on( '--top num_items', 'Return top n occurrences.') do | val |
      options[:number] = val.to_i
    end

    opts.on_tail('-h', '--help', 'Show this message') do
      puts opts
      exit(0)
    end
    opts.parse!(args)

    if not options[:key]
      $stderr.puts opts
      exit(1)
    end
  end



  options
end


summary = {}
opts = parse_command_line(ARGV)
key  = opts[:key]

$stdin.each_line do |line|
  json = Oj.load(line.to_s.unpack("C*").pack("C*").strip) rescue nil
  next unless json

  val = json[key]
  next unless val
  
  summary[val] ||= 0
  summary[val] += 1
end

output = {}
summary.keys.sort{|a,b| summary[b] <=> summary[a] }[0, opts[:number]].each do |k|
  output[k] = summary[k]
end

$stdout.puts Oj.dump(output)

