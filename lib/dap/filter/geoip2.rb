require 'maxmind/db'

module Dap
module Filter

require 'dap/utils/misc'

module GeoIP2Library
  GEOIP_DIRS = [
    File.expand_path( File.join( File.dirname(__FILE__), "..", "..", "..", "data")),
    "/var/lib/geoip",
    "/var/lib/geoip2"
  ]
  GEOIP_CITY = %W{ GeoLite2-City.mmdb }
  GEOIP_ASN = %W{ GeoLite2-ASN.mmdb }

  @@geo_city = nil
  @@geo_asn = nil

  GEOIP2_CITY_DATABASE_PATH = ENV["GEOIP2_CITY_DATABASE_PATH"]
  GEOIP2_ASN_DATABASE_PATH = ENV["GEOIP2_ASN_DATABASE_PATH"]

  if GEOIP2_CITY_DATABASE_PATH
    if ::File.exist?(GEOIP2_CITY_DATABASE_PATH)
      @@geo_city = MaxMind::DB.new(GEOIP2_CITY_DATABASE_PATH, mode: MaxMind::DB::MODE_MEMORY)
    end
  else
    GEOIP_DIRS.each do |d|
      GEOIP_CITY.each do |f|
        path = File.join(d, f)
        if ::File.exist?(path)
          @@geo_city = MaxMind::DB.new(path, mode: MaxMind::DB::MODE_MEMORY)
          break
        end
      end
    end
  end

  if GEOIP2_ASN_DATABASE_PATH
    if ::File.exist?(GEOIP2_ASN_DATABASE_PATH)
      @@geo_asn = MaxMind::DB.new(GEOIP2_ASN_DATABASE_PATH, mode: MaxMind::DB::MODE_MEMORY)
    end
  else
    GEOIP_DIRS.each do |d|
      GEOIP_ASN.each do |f|
        path = File.join(d, f)
        if ::File.exist?(path)
          @@geo_asn = MaxMind::DB.new(path, mode: MaxMind::DB::MODE_MEMORY)
          break
        end
      end
    end
  end
end


#
# Add GeoIP2 tags using the MaxMind GeoIP2::City
#
class FilterGeoIP2City
  include BaseDecoder
  include GeoIP2Library

  GEOIP2_LANGUAGE = ENV["GEOIP2_LANGUAGE"] || "en"
  LOCALE_SPECIFIC_NAMES = %w(city.names continent.names country.names registered_country.names)
  DESIRED_GEOIP2_KEYS = %w(\
    city.geoname_id \
    continent.code continent.geoname_id \
    country.geoname_id country.iso_code country.is_in_european_union \
    location.accuracy_radius location.latitude location.longitude location.time_zone \
    postal.code \
    registered_country.geoname_id registered_country.iso_code registered_country.is_in_european_union \
  )

  attr_reader :locale_specific_names
  def initialize(args={})
    @locale_specific_names = LOCALE_SPECIFIC_NAMES.map { |lsn| "#{lsn}.#{GEOIP2_LANGUAGE}" }
    super
  end

  def decode(ip)
    unless @@geo_city
      raise "No MaxMind GeoIP2::City data found"
    end
    return unless (geo_hash = @@geo_city.get(ip))
    ret = {}

    if geo_hash.include?("subdivisions")
      # handle countries that are divided into various subdivisions.  generally 1, sometimes 2
      subdivisions = geo_hash["subdivisions"]
      geo_hash.delete("subdivisions")
      ret["geoip2.subdivisions.length"] = subdivisions.size.to_s
      subdivisions.each_index do |i|
        subdivision = subdivisions[i]
        subdivision.each_pair do |k,v|
          if %w(geoname_id iso_code).include?(k)
            ret["geoip2.subdivisions.#{i+1}.#{k}"] = v.to_s
          elsif k == "names"
            if v.include?(GEOIP2_LANGUAGE)
              ret["geoip2.subdivisions.#{i+1}.name"] = subdivision["names"][GEOIP2_LANGUAGE]
            end
          end
        end
      end
    end

    Dap::Utils::Misc.flatten_hash(geo_hash).each_pair do |k,v|
      if DESIRED_GEOIP2_KEYS.include?(k)
        # these keys we can just copy directly over
        ret["geoip2.city.#{k}"] = v
      elsif @locale_specific_names.include?(k)
        # these keys we need to pick the locale-specific name and set the key accordingly
        lsn_renamed = k.gsub(/\.names.#{GEOIP2_LANGUAGE}/, ".name")
        ret["geoip2.city.#{lsn_renamed}"] = v
      end
    end
    ret
  end
end

#
# Add GeoIP2 ASN and Org tags using the MaxMind GeoIP2::ASN database
#
class FilterGeoIP2Asn
  include BaseDecoder
  include GeoIP2Library
  def decode(ip)
    unless @@geo_asn
      raise "No MaxMind GeoIP2::ASN data found"
    end
    geo_hash = @@geo_asn.get(ip)
    return unless (geo_hash && geo_hash.keys == %w(autonomous_system_number autonomous_system_organization))
    { "geoip2.asn.asn": "AS#{geo_hash["autonomous_system_number"]}", "geoip2.asn.asn_org": geo_hash["autonomous_system_organization"] }
  end
end

end
end
