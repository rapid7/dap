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
      :key => nil,
      :number => nil
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
    options
  end
  options
end

# Sorts the hash in descending numerical value for the values
# part of the hash, returning the sorted hash.
#
def order_hash(h)
  keys = h.keys.sort { | k1,k2 |
    ret = ( h[k1] <=> h[k2] ) * -1
    ret = k1 <=> k2 if ret == 0 && k1!=nil && k2!=nil
    ret
  }
  # build up return hash
  ret_hash = {}
  keys.each do | key |
    ret_hash[key] = h[key]
  end

  ret_hash
end




  summary={}
  opts = parse_command_line(ARGV)
  key = opts[:key]

  while line = gets
    val = Oj.load(line.chomp.strip)[key]
    summary[val] ||= 0
    summary[val] += 1
  end

  summary = Hash[ *order_hash(summary).flatten.slice(0,2*opts[:number]) ]
  puts Oj.dump(summary)

