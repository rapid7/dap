module Dap
module Filter

#
# Add GeoIP tags using the MaxMind GeoIP::City database
#
class FilterGeoIP
  include BaseDecoder

  require 'geoip'
  GEOIP_DATA = '/var/lib/geoip/geoip.dat'
  @@geo_lookup = nil
  if ::File.exist?( GEOIP_DATA )
    @@geo_lookup = GeoIP::City.new( GEOIP_DATA )
  end
  def decode(ip)
    return unless @@geo_lookup
    geo_hash = @@geo_lookup.look_up(ip)
    return unless geo_hash
    ret = {}
    geo_hash.each_pair do |k,v|
      next unless k
      ret[k.to_s] = v.to_s
    end
    
    ret
  end
end
end
end