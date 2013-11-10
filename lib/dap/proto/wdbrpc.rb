# -*- coding: binary -*-
module Dap
module Proto
class WDBRPC

  def self.wdbrpc_checksum(data)
    sum = 0
    data.unpack("n*").each {|c| sum += c }
    sum = (sum & 0xffff) + (sum >> 16)
    (~sum)
  end

  def self.wdbrpc_decode_str(data)
    return if data.length < 4
    slen = data.slice!(0,4).unpack("N")[0]
    return "" if slen == 0
    while (slen % 4 != 0)
      slen += 1
    end

    data.slice!(0,slen).to_s.split("\x00")[0]
  end

  def self.wdbrpc_decode_int(data)
    return if data.length < 4
    data.slice!(0,4).unpack("N")[0]
  end

  def self.wdbrpc_decode_arr(data, dtype)
    return if data.length < 4
    res = []

    alen = data.slice!(0,4).unpack("N")[0]
    return res if alen == 0

    1.upto(alen) do |idx|
      case dtype
      when :int
        res << wdbrpc_decode_int(data)
      when :str
        res << wdbrpc_decode_str(data)
      when :bool
        res << wdbrpc_decode_bool(data)
      end
    end

    res
  end

  def self.wdbrpc_decode_bool(data)
    return if data.length < 4
    (data.slice!(0,4).unpack("N")[0] == 0) ? false : true
  end


end
end
end