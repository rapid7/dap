#!/usr/bin/env ruby
require 'oj'
require 'optparse'

class GeoIPSummary
  attr_accessor :country_name, :region_name, :city_name, :tree
  #
  # Pass the hash keys for the country name, region name and
  # city name that we'll encounter during the process_hash function.
  #
  def initialize(country_name, region_name, city_name)
    @country_name = country_name
    @region_name = region_name
    @city_name = city_name
    @tree = {}
    @tree['count'] = 0
  end

  def process_hash( json_hash )
    country = json_hash[@country_name]
    region  = json_hash[@region_name] || 'Undefined Region'
    city    = json_hash[@city_name]   || 'Undefined City'

    # Create subhashes and values as needed on down the tree
    @tree[country] ||= {}
    @tree[country]['count'] ||=0
    @tree[country][region] ||= {}
    @tree[country][region]['count'] ||= 0
    @tree[country][region][city] ||= 0

    # Now increment counters
    @tree['count'] += 1
    @tree[country]['count'] += 1
    @tree[country][region]['count'] +=1
    @tree[country][region][city] += 1
  end

  # Performs the final sorting of the hash, with descending order of counts
  #
  def order_tree
    @tree.each do | country, country_hash|
      if country != 'count'
        country_hash.each do | region, region_hash |
          @tree[country][region] = order_hash(@tree[country][region]) if region != 'count'
        end
        @tree[country] = order_hash(@tree[country])
      end
    end
    @tree = order_hash(@tree)
  end

  private

  # Sorts the hash, and returns a copy of the hash in sorted order by their counts, or if
  # counts are equal then by their names.
  def order_hash(h)
    keys = h.keys.sort { | k1,k2 |
      if k1 == 'count'
        ret = -1
      elsif k2 == 'count'
        ret = 1
      else
        # Cities level is slightly different form, if hash at this level then compare
        # count value within hash, otherwise just compare values. mult by -1 to reverse
        # ordering
        if h[k1].class == Hash
          ret = ( h[k1]['count'] <=> h[k2]['count'] ) * -1
          ret = k1 <=> k2 if ret == 0 && k1!=nil && k2!=nil
        else
          ret = ( h[k1] <=> h[k2] ) * -1
          ret = k1 <=> k2 if ret == 0 && k1!=nil && k2!=nil
        end
      end
      ret
    }

    # build up return hash
    ret_hash = {}
    keys.each do | key |
      ret_hash[key] = h[key]
    end

    ret_hash
  end
end
HELP=<<EOF
 This script is used to summarize geoip data from data in a json file. The name of the json element for
 the country, region, and city must be provided. The output is a hash with the country/region/city data and
 the count of occurrences from the input file; this output hash is sorted in count descending order so that
 the most common country, region within a country, and city within a region is returned first.

 Example with dap:
   bzcat ../samples/ssl_certs.bz2 | ../bin/dap json + select host_ip + geo_ip host_ip + json | ./geo-ip-summary.rb --var host_ip > /tmp/ssl_geo.json
EOF

def parse_command_line(args)

  options={
      :country => nil,
      :region => nil,
      :city => nil,
      :var => nil
  }

  OptionParser.new do | opts |
    opts.banner = HELP
    opts.separator ''

    opts.separator 'GeoIP name options:'

    opts.on( '--country country_key', 'The name of json key for the country.') do | val |
      options[:country] = val
    end

    opts.on( '--region region_key', 'The name of the json key for the region.') do | val |
      options[:region] = val
    end

    opts.on( '--city city_key', 'The name of the json key for the city.' ) do | val |
      options[:city] = val
    end

    opts.on('--var top-level-var', 'Sets the top level json name, for defining all of country/region/city') do | val |
      options[:var] = val
      options[:country] = "#{val}.country_name"
      options[:region] = "#{val}.region"
      options[:city]   = "#{val}.city"
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
  opts = parse_command_line(ARGV)
  raise 'Need json key names for country,region and city.' if opts[:country].nil? || opts[:region].nil? || opts[:city].nil?

  summarizer = GeoIPSummary.new(opts[:country], opts[:region], opts[:city])
  while line=gets
    summarizer.process_hash(Oj.load(line.strip))
  end

  Oj.default_options={:indent=>2}

  puts Oj.dump(summarizer.order_tree)
