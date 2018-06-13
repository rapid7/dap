require 'geoip'

module Dap
module Filter

module GeoIPLibrary
  GEOIP_DIRS = [
    File.expand_path( File.join( File.dirname(__FILE__), "..", "..", "..", "data")),
    "/var/lib/geoip"
  ]
  GEOIP_CITY = %W{ geoip.dat geoip_city.dat GeoCity.dat IP_V4_CITY.dat GeoCityLite.dat }
  GEOIP_ORGS = %W{ geoip_org.dat IP_V4_ORG.dat }
  GEOIP_ASN = %W{ GeoIPASNum.dat }

  @@geo_city = nil
  @@geo_orgs = nil
  @@geo_asn = nil

  GEOIP_DIRS.each do |d|
    GEOIP_CITY.each do |f|
      path = File.join(d, f)
      if ::File.exist?(path)
        @@geo_city = GeoIP::City.new(path)
        break
      end
    end
    GEOIP_ORGS.each do |f|
      path = File.join(d, f)
      if ::File.exist?( path )
        @@geo_orgs = GeoIP::Organization.new(path)
        break
      end
    end
    GEOIP_ASN.each do |f|
      path = File.join(d, f)
      if ::File.exist?(path)
        @@geo_asn = GeoIP::Organization.new(path)
        break
      end
    end
  end
end


#
# Add GeoIP tags using the MaxMind GeoIP::City
#
class FilterGeoIP
  include BaseDecoder
  include GeoIPLibrary
  def decode(ip)
    unless @@geo_city
      raise "No MaxMind GeoIP::City data found"
    end
    geo_hash = @@geo_city.look_up(ip)
    return unless geo_hash
    ret = {}
    geo_hash.each_pair do |k,v|
      next unless k
      ret[k.to_s] = v.to_s
    end

    ret
  end
end

#
# Add GeoIP tags using the MaxMind GeoIP::Organization database
#
class FilterGeoIPOrg
  include BaseDecoder
  include GeoIPLibrary
  def decode(ip)
    unless @@geo_orgs
      raise "No MaxMind GeoIP::Organization data found"
    end
    geo_hash = @@geo_orgs.look_up(ip)
    return unless (geo_hash and geo_hash[:name])
    { :org => geo_hash[:name] }
  end
end

#
# Add GeoIP ASN tags using the MaxMind GeoIP::ASN database
#
class FilterGeoIPAsn
  include BaseDecoder
  include GeoIPLibrary
  def decode(ip)
    unless @@geo_asn
      raise "No MaxMind GeoIP::ASN data found"
    end
    geo_hash = @@geo_asn.look_up(ip)
    return unless (geo_hash and geo_hash[:name])
    { :asn => geo_hash[:name].split(' ')[0] }
  end
end

end
end
