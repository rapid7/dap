require 'geoip'

#GEOIP_DATA = '/Users/briangamble/Downloads/GeoLiteCity.dat'
GEOIP_DATA = '/Users/briangamble/Downloads/GEO-IP-DB/IP_V4_CITY.dat'
#GEOIP_DATA = '/Users/briangamble/Downloads/GEO-IP-DB/IP_V4_ORG.dat'

geo_lookup = GeoIP::City.new( GEOIP_DATA )

ip = gets.chomp
puts "ip=#{ip}"
p geo_lookup.look_up(ip)
