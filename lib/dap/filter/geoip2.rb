require 'maxmind/db'

module Dap
module Filter

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

  GEOIP_DIRS.each do |d|
    GEOIP_CITY.each do |f|
      path = File.join(d, f)
      if ::File.exist?(path)
        @@geo_city = MaxMind::DB.new(path, mode: MaxMind::DB::MODE_MEMORY)
        break
      end
    end
    GEOIP_ASN.each do |f|
      path = File.join(d, f)
      if ::File.exist?(path)
        @@geo_asn = MaxMind::DB.new(path, mode: MaxMind::DB::MODE_MEMORY)
        break
      end
    end
  end
end


#
# Add GeoIP2 tags using the MaxMind GeoIP2::City
#
class FilterGeoIP2
  include BaseDecoder
  include GeoIP2Library
  def decode(ip)
    unless @@geo_city
      raise "No MaxMind GeoIP2::City data found"
    end
    geo_hash = @@geo_city.get(ip)
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
# Add GeoIP2 org tags using the MaxMind GeoIP2::ASN database
#
class FilterGeoIP2Org
  include BaseDecoder
  include GeoIP2Library
  def decode(ip)
    unless @@geo_asn
      raise "No MaxMind GeoIP2::ASN data found"
    end
    geo_hash = @@geo_asn.get(ip)
    return unless (geo_hash and geo_hash['autonomous_system_organization'])
    { :org => geo_hash['autonomous_system_organization'] }
  end
end

#
# Add GeoIP2 ASN tags using the MaxMind GeoIP2::ASN database
#
class FilterGeoIP2Asn
  include BaseDecoder
  include GeoIP2Library
  def decode(ip)
    unless @@geo_asn
      raise "No MaxMind GeoIP2::ASN data found"
    end
    geo_hash = @@geo_asn.get(ip)
    return unless (geo_hash and geo_hash['autonomous_system_number'])
    { :asn => geo_hash['autonomous_system_number'].to_s }
  end
end

end
end
