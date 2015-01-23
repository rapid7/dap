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
        banner = $1
        save['banner'] = banner
        if banner =~ /^SSH-([\d\.]+)-([^\s]+)\s+(.*)/m
          save['ssh-protocol'] = $1
          save['ssh-version']  = $2
          save['ssh-vendor']   = $3
          save['ssh-recog']    = $2 + " " + $3
        end

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
