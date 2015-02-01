module Dap
module Filter

require 'digest/md5'

class FilterDecodeSMBClient
  include BaseDecoder

  def decode(data)
    save  = {}

    data.split(/\n/).each do |line|
      case line.strip
      when /^Domain=\[([^\]]+)\] OS=\[([^\]]+)\] Server=\[([^\]]+)\]/
        save['smb_domain'] = $1
        save['smb_native_os'] = $2
        save['smb_native_lm'] = $3
      end
    end

    save
  end
end

end
end
