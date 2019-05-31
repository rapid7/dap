require 'maxmind/db'

module Dap
module Filter

require 'dap/utils/misc'

module GeoIP2Library
  GEOIP2_DIRS = [
    File.expand_path( File.join( File.dirname(__FILE__), "..", "..", "..", "data")),
    "/var/lib/geoip",
    "/var/lib/geoip2"
  ]
  GEOIP2_CITY = %W{ GeoLite2-City.mmdb }
  GEOIP2_ASN = %W{ GeoLite2-ASN.mmdb }
  GEOIP2_ISP = %W{ GeoIP2-ISP.mmdb }

  def self.find_db(db_file_names, db_dirs, env_path)
    if env_path
      if ::File.exist?(env_path)
        return MaxMind::DB.new(env_path, mode: MaxMind::DB::MODE_MEMORY)
      end
    else
      db_dirs.each do |d|
        db_file_names.each do |f|
          path = File.join(d, f)
          if ::File.exist?(path)
            return MaxMind::DB.new(path, mode: MaxMind::DB::MODE_MEMORY)
          end
        end
      end
    end
    nil
  end

  def get_maxmind_data(db, ip)
    geo_hash = nil
    begin
      geo_hash = db.get(ip)
    rescue IPAddr::InvalidAddressError
    end

    geo_hash
  end

  def remove_empties(hash)
    hash.each_pair do |k,v|
      if v.empty?
        hash.delete(k)
      end
    end
    hash
  end

  @@geo_asn = find_db(GEOIP2_ASN, GEOIP2_DIRS, ENV["GEOIP2_ASN_DATABASE_PATH"])
  @@geo_city = find_db(GEOIP2_CITY, GEOIP2_DIRS, ENV["GEOIP2_CITY_DATABASE_PATH"])
  @@geo_isp = find_db(GEOIP2_ISP, GEOIP2_DIRS, ENV["GEOIP2_ISP_DATABASE_PATH"])
end


#
# Add GeoIP2 tags using the MaxMind GeoIP2::City
#
class FilterGeoIP2City
  include BaseDecoder
  include GeoIP2Library

  GEOIP2_LANGUAGE = ENV["GEOIP2_LANGUAGE"] || "en"
  LOCALE_SPECIFIC_NAMES = %w(city.names continent.names country.names registered_country.names represented_country.names)
  DESIRED_GEOIP2_KEYS = %w(
    city.geoname_id
    continent.code continent.geoname_id
    country.geoname_id country.iso_code country.is_in_european_union
    location.accuracy_radius location.latitude location.longitude location.metro_code location.time_zone
    postal.code
    registered_country.geoname_id registered_country.iso_code registered_country.is_in_european_union
    represented_country.geoname_id represented_country.iso_code represented_country.is_in_european_union represented_country.type
    traits.is_anonymous_proxy traits.is_satellite_provider
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

    ret = defaults
    return unless (geo_hash = get_maxmind_data(@@geo_city, ip))

    if geo_hash.include?("subdivisions")
      # handle countries that are divided into various subdivisions.  generally 1, sometimes 2
      subdivisions = geo_hash["subdivisions"]
      geo_hash.delete("subdivisions")
      ret["geoip2.city.subdivisions.length"] = subdivisions.size.to_s
      subdivisions.each_index do |i|
        subdivision = subdivisions[i]
        subdivision.each_pair do |k,v|
          if %w(geoname_id iso_code).include?(k)
            ret["geoip2.city.subdivisions.#{i}.#{k}"] = v.to_s
          elsif k == "names"
            if v.include?(GEOIP2_LANGUAGE)
              ret["geoip2.city.subdivisions.#{i}.name"] = subdivision["names"][GEOIP2_LANGUAGE]
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

    remove_empties(ret)
  end

  def defaults()
    ret = {}
    default_int_suffixes = %w(geoname_id metro_code)
    default_bool_suffixes = %w(is_in_european_union is_anonymous_proxy is_satellite_provider)
    DESIRED_GEOIP2_KEYS.each do |k|
      suffix = k.split(/\./)[-1]
      if default_int_suffixes.include?(suffix)
        ret["geoip2.city.#{k}"] = "0"
      elsif default_bool_suffixes.include?(suffix)
        ret["geoip2.city.#{k}"] = "false"
      else
        ret["geoip2.city.#{k}"] = ""
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

    ret = {}
    return unless (geo_hash = get_maxmind_data(@@geo_asn, ip))

    if geo_hash.include?("autonomous_system_number")
      ret["geoip2.asn.asn"] = "AS#{geo_hash["autonomous_system_number"]}"
    else
      ret["geoip2.asn.asn"] = ""
    end

    if geo_hash.include?("autonomous_system_organization")
      ret["geoip2.asn.asn_org"] = "#{geo_hash["autonomous_system_organization"]}"
    else
      ret["geoip2.asn.asn_org"] = ""
    end

    remove_empties(ret)
  end
end

#
# Add GeoIP2 ISP tags using the MaxMind GeoIP2::ISP database
#
class FilterGeoIP2Isp
  include BaseDecoder
  include GeoIP2Library
  def decode(ip)
    unless @@geo_isp
      raise "No MaxMind GeoIP2::ISP data found"
    end

    ret = {}
    return unless (geo_hash = get_maxmind_data(@@geo_isp, ip))

    if geo_hash.include?("autonomous_system_number")
      ret["geoip2.isp.asn"] = "AS#{geo_hash["autonomous_system_number"]}"
    else
      ret["geoip2.isp.asn"] = ""
    end

    if geo_hash.include?("autonomous_system_organization")
      ret["geoip2.isp.asn_org"] = geo_hash["autonomous_system_organization"]
    else
      ret["geoip2.isp.asn_org"] = ""
    end

    if geo_hash.include?("isp")
      ret["geoip2.isp.isp"] = geo_hash["isp"]
    else
      ret["geoip2.isp.isp"] = ""
    end

    if geo_hash.include?("organization")
      ret["geoip2.isp.org"] = geo_hash["organization"]
    else
      ret["geoip2.isp.org"] = ""
    end

    remove_empties(ret)
  end
end

#
# Convert GeoIP2 data as closely as possible to the legacy GeoIP data as generated by geo_ip, geo_ip_asn and geo_ip_org
#
class FilterGeoIP2LegacyCompat
  include Base
  include GeoIP2Library

  attr_accessor :base_field

  def initialize(args)
    super
    fail "Expected 1 arguments to '#{self.name}' but got #{args.size}" unless args.size == 1
    self.base_field = args.first
  end

  def process(doc)
    # all of these values we just take directly and rename
    remap = {
      # geoip2 name -> geoip name
      "city.country.iso_code": "country_code",
      "city.country.name": "country_name",
      "city.postal.code": "postal_code",
      "city.location.latitude": "latitude",
      "city.location.longitude": "longitude",
      "city.city.name": "city",
      "city.subdivisions.0.iso_code": "region",
      "city.subdivisions.0.name": "region_name",
      "asn.asn": "asn",
      "isp.asn": "asn",
    }

    ret = {}
    remap.each_pair do |geoip2,geoip|
      geoip2_key = "#{self.base_field}.geoip2.#{geoip2}"
      if doc.include?(geoip2_key)
        ret["#{self.base_field}.#{geoip}"] = doc[geoip2_key]
      end
    end

    # these values all require special handling

    # https://dev.maxmind.com/geoip/geoip2/whats-new-in-geoip2/#Custom_Country_Codes
    # which basically says if traits.is_anonymous_proxy is true, previously the
    # country_code would have had a special value of A1.  Similarly, if
    # traits.is_satellite_provider is true, previously the country_code would
    # have a special value of A2.
    anon_key = "#{self.base_field}.geoip2.city.traits.is_anonymous_proxy"
    if doc.include?(anon_key)
      anon_value = doc[anon_key]
      if anon_value == "true"
        ret["#{self.base_field}.country_code"] = "A1"
      end
    end

    satellite_key = "#{self.base_field}.geoip2.city.traits.is_satellite_provider"
    if doc.include?(satellite_key)
      satellite_value = doc[satellite_key]
      if satellite_value == "true"
        ret["#{self.base_field}.country_code"] = "A1"
      end
    end

    # only set dma_code if location.metro_code was set and not empty or 0
    metro_key = "#{self.base_field}.geoip2.city.location.metro_code}"
    if doc.include?(metro_key)
      metro_value = doc[metro_key]
      if !metro_value.empty? && metro_value != "0"
        ret["#{self.base_field}.dma_code"] = metro_value
      end
    end

    # get the org key from 3 possible fields in decreasing order of preference
    asn_org_key = "#{self.base_field}.geoip2.asn.asn_org"
    isp_asn_org_key = "#{self.base_field}.geoip2.isp.asn_org"
    isp_org_key = "#{self.base_field}.geoip2.isp.asn_org"
    [ isp_org_key, isp_asn_org_key, asn_org_key ].each do |k|
      v = doc[k]
      if v && !v.empty?
        ret["#{self.base_field}.org"] = v
        break
      end
    end

    [ doc.merge(remove_empties(ret)) ]
  end
end

end
end
