module Dap
module Filter

require 'digest/md5'

class FilterDecodeSSHKeyscan
  include BaseDecoder

  def decode(data)
    save  = {}

    data.split(/\n/).each do |line|
      case line.strip
      when /^# [0-9]+\.[0-9]+\.[0-9]+\.[0-9]+\s+(.*)/m
        save['banner'] = $1
      when /^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+\s+((ssh|ecdsa)[^\s]+)\s+(.*)/m
        ktype = $1
        kdata = $3

        save['hkey-' + ktype] = kdata
        save['hkey-' + ktype + '-fp'] = Digest::MD5.hexdigest(kdata.unpack('m*').first).scan(/../).join(':')
      end
    end

    save
  end
end

end
end
