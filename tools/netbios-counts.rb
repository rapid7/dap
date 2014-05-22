require 'optparse'
require 'ostruct'
require 'oj'
require 'geoip'

options = OpenStruct.new
options.top_count = 5
options.include_geo = true

OptionParser.new do |opts|
  opts.banner = "Usage: netbios-counts.rb [options]"

  opts.on("-c", "--count [NUM]", OptionParser::DecimalInteger, 
          "Specify the number of top results") do |count|
    options.top_count = count if count > 1
  end

  opts.on("--exclude-geo-data") do
    options.include_geo = false
  end
end.parse!

GEOIP_DATA = File.join(File.expand_path('../..', __FILE__), 'data', 'geoip.dat')
if options.include_geo
  unless File.exist?(GEOIP_DATA)
    puts "The geoip data file is missing."
    exit 1
  end
end

NUM_TOP_RECORDS = options.top_count

module Counter
  def count(hash)
    value = countable_value(hash).to_s
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
    hash['data.netbios_mac_company']
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
    hash['data.netbios_hname']
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
    unless hash['data.netbios_mac'].nil?
      company_name = hash['data.netbios_mac_company'].unpack("C*").pack("C*")
      "#{hash['data.netbios_mac']}|#{hash['data.netbios_hname']}|#{company_name}"
    end
  end

  def count_hash(values)
    mac_address_data = values[0].split('|') 
    { 
      'mac_address' => mac_address_data[0], 
      'name'        => mac_address_data[1],
      'company'     => mac_address_data[2],
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
    @geo_lookup ||= GeoIP::City.new( GEOIP_DATA )
  end

  def count(hash)
    geo_result = @geo_lookup.look_up(hash['ip']) 
    unless geo_result.nil?
      city         = geo_result.fetch(:city, '')
      country_code = geo_result.fetch(:country_code)

      @cities["#{city}|#{country_code}"] += 1 unless city.empty?
      @countries[country_code] += 1
    end
  end
  
  def top_cities
    [].tap do |counts|
      ordered_cities.to_a.take(NUM_TOP_RECORDS).each do |values|
        city_data = values[0].split('|')
        counts << { 
          'city'    => city_data[0], 
          'country' => city_data[1], 
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
    hash['top_cities']    = top_cities
    hash['top_countries'] = top_countries
  end
end

counters = [ 
  CompanyNameCounter.new, 
  NetbiosNameCounter.new,
  MacAddressCounter.new
]
counters << GeoCounter.new if options.include_geo

while line=gets
  hash = Oj.load(line.strip)
  counters.each { |counter| counter.count(hash) }
end

summary = {}
counters.each { |counter| counter.apply_to(summary) }

puts Oj.dump(summary)
