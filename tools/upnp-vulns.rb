#!/usr/bin/env ruby
require 'oj'

# Searches contains each of the services, within each service it contains
# a hash key that will be compared against each of the items in the
# regex hash, and if a hit is returned the value from the regex is inserted
# into the hash with the output_key as the key.
#
SEARCHES = {
    :upnp => {
      :hash_key   => 'data.upnp_server',
      :output_key => 'vulnerability',
      :regex      => {
        /MiniUPnPd\/1\.0([\.\,\-\~\s]|$)/mi     => ['CVE-2013-0229'],
        /MiniUPnPd\/1\.[0-3]([\.\,\-\~\s]|$)/mi => ['CVE-2013-0230'],
        /Intel SDK for UPnP devices.*|Portable SDK for UPnP devices(\/?\s*$|\/1\.([0-5]\..*|8\.0.*|(6\.[0-9]|6\.1[0-7])([\.\,\-\~\s]|$)))/mi => ['CVE-2012-5958', 'CVE-2012-5959']
      }
  }
}

def search(hash, service)
  SEARCHES[service][:regex].each do | regex, value |
    if regex =~ hash[SEARCHES[service][:hash_key]].force_encoding('BINARY')
      # Handle cases that could be multiple hits, not for upnp but could be others.
      hash[SEARCHES[service][:output_key]] = ( hash[SEARCHES[service][:output_key]] ? hash[SEARCHES[service][:output_key]] + value : value )
    end
  end if hash[SEARCHES[service][:hash_key]]
  hash
end

$stdin.each_line do |line|
  json = Oj.load(line.unpack("C*").pack("C*").strip) rescue nil
  next unless json
  puts Oj.dump(search(json, :upnp))
end
