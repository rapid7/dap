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


def stringify(o)
  o.kind_of?( ::String )
    o.to_s.encode(o.encoding, "UTF-8", :invalid => :replace, :undef => :replace, :replace => '')
  else
    o.to_s
  end
end

def parse_command_line(args)

  options = {
      :key    => nil,
      :number => 100,
      :subkey => nil,
      :subnumber => 100
  }

  OptionParser.new do | opts |
    opts.banner = HELP
    opts.separator ''

    opts.separator 'GeoIP name options:'

    opts.on( '--key keyname', 'The name of the json key to be summarized.') do | val |
      options[:key] = val
    end
    
    opts.on( '--subkey keyname', 'The name of the json subkey to be summarized under each key') do | val |
      options[:subkey] = val
    end

    opts.on( '--top num_items', 'Return top n occurrences.') do | val |
      options[:number] = val.to_i
    end
    
    opts.on( '--subtop num_items', 'Return top n occurrences in each subkey.') do | val |
      options[:subnumber] = val.to_i
    end

    opts.on_tail('-h', '--help', 'Show this message') do
      $stderr.puts puts opts
      exit(1)
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
skey = opts[:subkey]

$stdin.each_line do |line|
  json = Oj.load(line.to_s.unpack("C*").pack("C*").strip) rescue nil
  next unless ( json && json[key] )

  val = stringify(json[key])

  summary[val] ||= {}
  summary[val][:count] ||= 0
  summary[val][:count]  += 1

  if skey
    sval = stringify(json[skey])
    summary[val][sval] ||= {}
    summary[val][sval][:count] ||= 0
    summary[val][sval][:count]  += 1
  end

end

output = {}
summary.keys.sort{|a,b| summary[b][:count] <=> summary[a][:count] }[0, opts[:number]].each do |k|
  unless skey
    output[k] = summary[k][:count]
  else
    output[k] = { "count" => summary[k][:count], skey => {} }
    summary[k].keys.select{|x| x != :count}.sort{|a,b| summary[k][b][:count] <=> summary[k][a][:count] }[0, opts[:subnumber]].each do |sk|
      output[k][skey][sk] = summary[k][sk][:count]
    end
  end
end

$stdout.puts Oj.dump(output)