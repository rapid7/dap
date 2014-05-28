#!/usr/bin/env ruby

require 'optparse'
require 'ostruct'
require 'oj'
require 'json'

options = OpenStruct.new
options.top_count = 5

OptionParser.new do |opts|
  opts.banner = "Usage: netbios-counts.rb [options]"

  opts.on("-c", "--count [NUM]", OptionParser::DecimalInteger, 
          "Specify the number of top results") do |count|
    options.top_count = count if count > 1
  end
end.parse!

NUM_TOP_RECORDS = options.top_count

module Counter
  def count(hash)
    value = countable_value(hash)
    @counts[value] += 1 unless (value.empty? || value == 'UNKNOWN')
  end

  def top_counts
    [].tap do |counts|
      ordered_by_count.to_a.take(NUM_TOP_RECORDS).each do |values|
        counts << count_hash(values) 
      end
    end
  end

  def ordered_by_count
    Hash[@counts.sort_by{|k, v| v}.reverse] 
  end
end

class CompanyNameCounter
  include Counter

  def initialize
    @counts = Hash.new(0)
  end

  def countable_value(hash)
    hash['data.netbios_mac_company'].to_s
  end

  def count_hash(values)
    { 'name' => values[0], 'count' => values[1] }
  end

  def apply_to(hash)
    hash['top_companies'] = top_counts
  end
end

class NetbiosNameCounter
  include Counter

  def initialize
    @counts = Hash.new(0)
  end

  def countable_value(hash)
    hash['data.netbios_hname'].to_s
  end

  def count_hash(values)
    { 'hostname' => values[0], 'count' => values[1] }
  end

  def apply_to(hash)
    hash['top_netbios_hostnames'] = top_counts
  end
end

class MacAddressCounter
  include Counter

  def initialize
    @counts = Hash.new(0)
  end

  def countable_value(hash)
    address = hash['data.netbios_mac'].to_s
    [].tap do |data|
      unless (address.empty? || address == '00:00:00:00:00:00')
        data << address
        data << hash['data.netbios_hname']
        data << hash['data.netbios_mac_company']
      end
    end
  end

  def count_hash(values)
    { 
      'mac_address' => values[0][0], 
      'hostname'    => values[0][1],
      'company'     => values[0][2],
      'count'       => values[1] 
    }
  end

  def apply_to(hash)
    hash['top_mac_addresses'] = top_counts
  end
end

class GeoCounter
  def initialize
    @cities    = Hash.new(0)
    @countries = Hash.new(0)
    @regions   = Hash.new(0)
  end

  def count(hash)
    city         = hash['ip.city'].to_s
    country_code = hash['ip.country_code'].to_s
    region       = hash['ip.region'].to_s
    region_name  = hash['ip.region_name'].to_s

    @cities[[city, country_code]] += 1 unless city.empty?
    @countries[country_code] += 1 unless country_code.empty?
    @regions[[region, region_name]] += 1 unless region.empty?
  end
  
  def top_cities
    [].tap do |counts|
      ordered_cities.to_a.take(NUM_TOP_RECORDS).each do |values|
        counts << { 
          'city'    => values[0][0], 
          'country_code' => values[0][1], 
          'count'   => values[1] 
        }
      end
    end
  end

  def top_countries
    [].tap do |counts|
      ordered_countries.to_a.take(NUM_TOP_RECORDS).each do |values|
        counts << { 'country_code' => values[0], 'count' => values[1] }
      end
    end
  end

  def top_regions
    [].tap do |counts|
      ordered_regions.to_a.take(NUM_TOP_RECORDS).each do |values|
        counts << { 
          'region'      => values[0][0], 
          'region_name' => values[0][1], 
          'count'       => values[1] 
        }
      end
    end
  end

  def ordered_cities
    Hash[@cities.sort_by{|k, v| v}.reverse] 
  end

  def ordered_countries
    Hash[@countries.sort_by{|k, v| v}.reverse] 
  end

  def ordered_regions
    Hash[@regions.sort_by{|k, v| v}.reverse] 
  end

  def apply_to(hash)
    hash['top_cities']    = top_cities unless top_cities.empty?
    hash['top_countries'] = top_countries unless top_countries.empty?
    hash['top_regions']   = top_regions unless top_regions.empty?
  end
end

class SambaCounter
  include Counter

  def initialize
    @counts = Hash.new(0)
  end

  def countable_value(hash)
    address = hash['data.netbios_mac'].to_s
    if (address == '00:00:00:00:00:00')
      hash['data.netbios_hname']
    else
      ''
    end
  end

  def count_hash(values)
    { 'name'  => values[0], 'count' => values[1] }
  end

  def apply_to(hash)
    hash['top_samba_names'] = top_counts
  end
end

counters = [ 
  CompanyNameCounter.new, 
  NetbiosNameCounter.new,
  MacAddressCounter.new,
  GeoCounter.new,
  SambaCounter.new
]

while line=gets
  hash = Oj.load(line.strip)
  counters.each { |counter| counter.count(hash) }
end

summary = {}
counters.each { |counter| counter.apply_to(summary) }

puts JSON.pretty_generate(summary)
