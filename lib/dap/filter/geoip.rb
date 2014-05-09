require 'geoip_city'
# NOTE:
# For ruby 1.9.3 you must change source code because of STR2CSTR issue and rebuild gem. See https://github.com/yar/geoip-city/blob/master/geoip_city.c
#

GEOIP_DATA = '/var/lib/geoip/geoip.dat'
$geo_lookup = nil

# Load up geoip database into memory, and re-use this object for all later queries.
# If file not present leave global at nil process code will silently ignore lack of geoip data.
#
if File.exist?( GEOIP_DATA )
  $geo_lookup = GeoIPCity::Database.new( GEOIP_DATA )
end


module Dap
  module Filter

    class FilterGeoip
      include Base
      def process(doc)
        if $geo_lookup
          geo_data = {}
          self.opts.each_pair do |k,v|
            if doc.has_key?(k)
              geo_hash = $geo_lookup.look_up( doc[k] )
              geo_data['c']    = geo_hash[:country_code]
              geo_data['city'] = geo_hash[:city]
              geo_data['reg']  = geo_hash[:region]
              geo_data['loc']  = [ geo_hash[:latitude], geo_hash[:longitude]]
            end
          end
          doc['geo'] = geo_data
        end
        [doc]
      end
    end

  end
end
