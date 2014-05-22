require 'optparse'
require 'ostruct'
require 'oj'

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
    { 'name' => values[0], 'count' => values[1] }
  end

  def apply_to(hash)
    hash['top_netbios_names'] = top_counts
  end
end

class MacAddressCounter
  include Counter

  def initialize
    @counts = Hash.new(0)
  end

  def countable_value(hash)
    [].tap do |data|
      unless hash['data.netbios_mac'].nil?
        data << hash['data.netbios_mac']
        data << hash['data.netbios_hname']
        data << hash['data.netbios_mac_company']
      end
    end
  end

  def count_hash(values)
    { 
      'mac_address' => values[0][0], 
      'name'        => values[0][1],
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
  end

  def count(hash)
    city         = hash['ip.city'].to_s
    country_code = hash['ip.country_code'].to_s

    @cities[[city, country_code]] += 1 unless city.empty?
    @countries[country_code] += 1 unless country_code.empty?
  end
  
  def top_cities
    [].tap do |counts|
      ordered_cities.to_a.take(NUM_TOP_RECORDS).each do |values|
        counts << { 
          'city'    => values[0][0], 
          'country' => values[0][1], 
          'count'   => values[1] 
        }
      end
    end
  end

  def top_countries
    [].tap do |counts|
      ordered_countries.to_a.take(NUM_TOP_RECORDS).each do |values|
        counts << { 'country' => values[0], 'count' => values[1] }
      end
    end
  end

  def ordered_cities
    Hash[@cities.sort_by{|k, v| v}.reverse] 
  end

  def ordered_countries
    Hash[@countries.sort_by{|k, v| v}.reverse] 
  end

  def apply_to(hash)
    hash['top_cities']    = top_cities unless top_cities.empty?
    hash['top_countries'] = top_countries unless top_countries.empty?
  end
end

counters = [ 
  CompanyNameCounter.new, 
  NetbiosNameCounter.new,
  MacAddressCounter.new,
  GeoCounter.new
]

while line=gets
  hash = Oj.load(line.strip)
  counters.each { |counter| counter.count(hash) }
end

summary = {}
counters.each { |counter| counter.apply_to(summary) }

puts Oj.dump(summary)
