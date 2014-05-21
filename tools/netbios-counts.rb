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

module NameCounter
  def count(hash)
    name = hash[field].to_s
    @names[name] += 1 unless (name.empty? || name == 'UNKNOWN')
  end

  def top_names
    [].tap do |counts|
      ordered_names.to_a.take(NUM_TOP_RECORDS).each do |values|
        counts << { 'name' => values[0], 'count' => values[1] }
      end
    end
  end

  def ordered_names
    Hash[@names.sort_by{|k, v| v}.reverse] 
  end
end

class CompanyNameCounter
  include NameCounter

  def initialize
    @names = Hash.new(0)
  end

  def field
    'data.netbios_mac_company'
  end

  def apply_to(hash)
    hash['top_companies'] = top_names
  end
end

class NetbiosNameCounter
  include NameCounter

  def initialize
    @names = Hash.new(0)
  end

  def field
    'data.netbios_hname'
  end

  def apply_to(hash)
    hash['top_netbios_names'] = top_names
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

counters = [ CompanyNameCounter.new, NetbiosNameCounter.new ]
counters << GeoCounter.new if options.include_geo

while line=gets
  hash = Oj.load(line.strip)
  counters.each { |counter| counter.count(hash) }
end

summary = {}
counters.each { |counter| counter.apply_to(summary) }

puts Oj.dump(summary)
