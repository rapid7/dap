module Dap
module Filter

require 'openssl'
require 'net/dns'
require 'bit-struct'

require 'dap/proto/addp'
require 'dap/proto/natpmp'
require 'dap/proto/wdbrpc'
require 'dap/proto/ipmi'

require_relative '../../rex/mac_oui'

#
# Decode a MDNS Services probe response ( zmap: mdns_5353.pkt )
#
class FilterDecodeMDNSSrvReply
  include BaseDecoder
  def decode(data)
    begin
      r = Net::DNS::Packet.parse(data)
      return if not r

      # XXX: This can throw an exception on bad data
      svcs = r.answer.map {|x| (x.value.to_s) }
      svcs.delete('')
      return if not (svcs and svcs.length > 0)
      return { "mdns_services" => svc.join(" ") }
    rescue ::Exception
    end
    nil
  end
end

#
# Decode a DNS bind.version probe response ( zmap: dns_53.pkt )
#
class FilterDecodeDNSVersionReply
  include BaseDecoder
  def decode(data)
    begin
      r = Net::DNS::Packet.parse(data)
      return if not r

      # XXX: This can throw an exception on bad data
      vers = r.answer.map{|x| x.txt.strip rescue nil }.reject{|x| x.nil? }.first
      return if not vers
      return { "dns_version" => vers }
    rescue ::Exception
      { }
    end
  end
end

#
# Decode a SSDP probe response ( zmap: upnp_1900.pkt )
#
class FilterDecodeUPNP_SSDP_Reply
  include BaseDecoder
  def decode(data)
    head = { }
    data.split(/\n/).each do |line|
      k,v = line.strip.split(':', 2)
      next if not k
      head["upnp_#{k.downcase}"] = (v.to_s.strip)
    end
    head
  end
end

#
# Decode a VxWorks WDBRPC probe response ( zmap: wdbrpc_17185.pkt )
#
class FilterDecodeWDBRPC_Reply
  include BaseDecoder
  def decode(data)
    info = {}
    head = buff.slice!(0,36)
    info['agent_ver'] = wdbrpc_decode_str(buff)
    info['agent_mtu'] = wdbrpc_decode_int(buff)
    info['agent_mod'] = wdbrpc_decode_int(buff)
    info['rt_type']          = wdbrpc_decode_int(buff)
    info['rt_vers']          = wdbrpc_decode_str(buff)
    info['rt_cpu_type']      = wdbrpc_decode_int(buff)
    info['rt_has_fpp']       = wdbrpc_decode_bool(buff)
    info['rt_has_wp']        = wdbrpc_decode_bool(buff)
    info['rt_page_size']     = wdbrpc_decode_int(buff)
    info['rt_endian']        = wdbrpc_decode_int(buff)
    info['rt_bsp_name']      = wdbrpc_decode_str(buff)
    info['rt_bootline']      = wdbrpc_decode_str(buff)
    info['rt_membase']       = wdbrpc_decode_int(buff)
    info['rt_memsize']       = wdbrpc_decode_int(buff)
    info['rt_region_count']  = wdbrpc_decode_int(buff)
    info['rt_regions']       = wdbrpc_decode_arr(buff, :int)
    info['rt_hostpool_base'] = wdbrpc_decode_int(buff)
    info['rt_hostpool_size'] = wdbrpc_decode_int(buff)
    info
  end
end

#
# Decode a SNMP GET probe response ( zmap: snmp1_161.pkt )
#
class FilterDecodeSNMPGetReply
  include BaseDecoder
  def decode(data)
    asn = OpenSSL::ASN1.decode(data) rescue nil
    return if not asn

    snmp_error = asn.value[0].value rescue nil
    snmp_comm  = asn.value[1].value rescue nil
    snmp_data  = asn.value[2].value[3].value[0] rescue nil
    snmp_oid   = snmp_data.value[0].value rescue nil
    snmp_info  = snmp_data.value[1].value rescue nil

    return if not (snmp_error and snmp_comm and snmp_data and snmp_oid and snmp_info)
    snmp_info = snmp_info.to_s.gsub(/\s+/, ' ').gsub(/[\x00-\x1f]/, ' ')

    return if not snmp_info
    { 'snmp_value' => snmp_info }
  end
end

#
# Decode a IPMI GetChannelAuth probe response ( zmap: ipmi_623.pkt )
#
class FilterDecodeIPMIChanAuthReply
  include BaseDecoder
  def decode(data)
    info = Dap::Proto::IPMI::Channel_Auth_Reply.new(data)
    return unless info.valid?
    {}.tap do |h|
      info.fields.each do |f|
        name = f.name
        h[name] = info.send(name).to_s
      end
    end
  end
end

#
# Decode a NAT-PMP External Address response
#
class FilterDecodeNATPMPExternalAddressResponse
  include BaseDecoder
  def decode(data)
    return unless (data && data.size == Dap::Proto::NATPMP::REQUIRED_SIZE)
    info = Dap::Proto::NATPMP::ExternalAddressResponse.new(data)
    {}.tap do |h|
      info.fields.each do |f|
        name = f.name
        h[name] = info.send(name).to_s
      end
    end
  end
end

#
# Decode a NetBIOS status probe response ( zmap: netbios_137.pkt )
#
class FilterDecodeNetbiosStatusReply
  include BaseDecoder
  def decode(data)
    ret = {}
    head = data.slice!(0,12)

    xid, flags, quests, answers, auths, adds = head.unpack('n6')
    return if quests != 0
    return if answers == 0

    qname = data.slice!(0,34)
    rtype,rclass,rttl,rlen = data.slice!(0,10).unpack('nnNn')
    return if not rlen

    buff = data.slice!(0,rlen)

    names = []

    case rtype
    when 0x21
      hname = nil
      inf = ''
      rcnt = buff.slice!(0,1).unpack("C")[0]
      return unless rcnt
      1.upto(rcnt) do
        tname = buff.slice!(0,15).gsub(/\x00.*/, '').strip
        ttype = buff.slice!(0,1).unpack("C")[0]
        tflag = buff.slice!(0,2).unpack('n')[0]
        names << [ tname, ttype, tflag ]
      end

      maddr = buff.slice!(0,6).unpack("C*").map{|c| "%.2x" % c }.join(":")
      names.each do |name|
        inf << name[0]

        next unless name[1]
        inf << ":%.2x" % name[1]

        next unless name[2]
        if (name[2] & 0x8000 == 0)
          inf << ":U "
        else
          inf << ":G "
        end
      end
    end

    return unless names.length > 0

    {}.tap do |hash|
      hash['netbios_names'] = (inf)
      hash['netbios_mac']   = maddr
      hash['netbios_hname'] = names[0][0]
      unless maddr == '00:00:00:00:00:00'
        hash['netbios_mac_company']      = mac_company(maddr)
        hash['netbios_mac_company_name'] = mac_company_name(maddr)
      end
    end
  end

  def mac_company(address)
    begin
      name = Rex::Oui.lookup_oui_fullname(address)
      name.split("/").first.strip
    rescue => error
      ''
    end
  end

  def mac_company_name(address)
    begin
      Rex::Oui.lookup_oui_company_name(address)
    rescue => error
      ''
    end
  end
end
#
# Decode a MSSQL reply
#
class FilterDecodeMSSQLReply
  include BaseDecoder
  def decode(data)
    info = {}
    # Some binary characters often proceed key, restrict to alphanumeric and a few other common chars
    data.scan(/([A-Za-z0-9 \.\-_]+?);(.+?);/).each do | var, val|
      info["mssql.#{var.encode!( 'UTF-8', invalid: :replace, undef: :replace, replace: '' )}"] = val.encode!( 'UTF-8', invalid: :replace, undef: :replace, replace: '' )
    end
    info
  end
end

#
# Decode a SIP OPTIONS Reply
#
class FilterDecodeSIPOptionsReply
  include BaseDecoder
  def decode(data)
    info = {}
    data.split(/\r?\n/).each do |line|
      case line
      when /^SIP\/(\d+\.\d+) (\d+)(.*)/
        info['sip_version'] = $1
        info['sip_code']    = $2
        if $3.length > 0
          info['sip_message'] = $3.strip
        end
      when /^([a-zA-z0-9][^:]+):(.*)/
        var = $1.strip
        val = $2.strip
        var = var.downcase.gsub(/[^a-zA-Z0-9_]/, '_').gsub(/_+/, '_')
        info["sip_#{var}"] = val
      end
    end
    info
  end
end

#
# Decode a NTP reply
#
class FilterDecodeNTPReply
  include BaseDecoder
  def decode(sdata)
    info = {}
    return if sdata.length < 4

    # Make a copy since our parser is destructive
    data = sdata.dup

    # TODO: all of this with bitstruct?
    # The format of the packet depends largely on the version, so extract just the version.
    # Fortunately the version is in the same place regardless of NTP protocol version --
    # The 3rd-5th bits of the first byte of the response
    ntp_flags = data.slice!(0,1).unpack('C').first
    ntp_version = (ntp_flags & 0b00111000) >> 3
    info['ntp.version'] = ntp_version

    # NTP 2 & 3 share a common header, so parse those together
    if ntp_version == 2 || ntp_version == 3
      #     0                   1                   2                   3
      #     0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1
      #    +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
      #    |R|M| VN  | Mode|A|  Sequence   | Implementation|   Req Code    |
      #    +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+

      info['ntp.response'] = ntp_flags >> 7
      info['ntp.more'] = (ntp_flags & 0b01000000) >> 6
      info['ntp.mode'] = (ntp_flags & 0b00000111)
      ntp_auth_seq, ntp_impl, ntp_rcode = data.slice!(0,3).unpack('C*')
      info['ntp.implementation'] = ntp_impl
      info['ntp.request_code'] = ntp_rcode

      # if it is mode 7, parse that:
      #     0                   1                   2                   3
      #     0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1
      #    +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
      #    |  Err  | Number of data items  |  MBZ  |   Size of data item   |
      #    +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
      #    ... data ...
      if info['ntp.mode'] == 7
        mode7_data = data.slice!(0,4).unpack('n*')
        info['ntp.mode7.err'] = mode7_data.first >> 11
        info['ntp.mode7.data_items_count'] = mode7_data.first & 0b0000111111111111
        info['ntp.mode7.mbz'] = mode7_data.last >> 11
        info['ntp.mode7.data_item_size'] = mode7_data.last & 0b0000111111111111

        # extra monlist response data
        if ntp_rcode == 42
          if info['ntp.mode7.data_item_size'] == 72
            remote_addresses = []
            local_addresses = []
            idx = 0
            1.upto(info['ntp.mode7.data_items_count']) do

              #u_int32 firsttime; /* first time we received a packet */
              #u_int32 lasttime;  /* last packet from this host */
              #u_int32 restr;     /* restrict bits (was named lastdrop) */
              #u_int32 count;     /* count of packets received */
              #u_int32 addr;      /* host address V4 style */
              #u_int32 daddr;     /* destination host address */
              #u_int32 flags;     /* flags about destination */
              #u_short port;      /* port number of last reception */

              firsttime,lasttime,restr,count,raddr,laddr,flags,dport = data[idx, 30].unpack("NNNNNNNn")
              remote_addresses << [raddr].pack("N").unpack("C*").map{|x| x.to_s }.join(".")
              local_addresses << [laddr].pack("N").unpack("C*").map{|x| x.to_s }.join(".")
              idx += info['ntp.mode7.data_item_size']
            end

            info['ntp.monlist.remote_addresses'] = remote_addresses.join(' ')
            info['ntp.monlist.remote_addresses.count'] = remote_addresses.size
            info['ntp.monlist.local_addresses'] = local_addresses.join(' ')
            info['ntp.monlist.local_addresses.count'] = local_addresses.size
          end
        end
      end
    elsif ntp_version == 4
      info['ntp.leap_indicator'] = ntp_flags >> 6
      info['ntp.mode'] = ntp_flags & 0b00000111
      info['ntp.peer.stratum'], info['ntp.peer.interval'], info['ntp.peer.precision'] = data.slice!(0,3).unpack('C*')
      info['ntp.root.delay'], info['ntp.root.dispersion'], info['ntp.ref_id'] = data.slice!(0,12).unpack('N*')
      info['ntp.timestamp.reference'], info['ntp.timestamp.origin'], info['ntp.timestamp.receive'], info['ntp.timestamp.transmit'] = data.slice!(0,32).unpack('Q*')
    end

    info
  end
end

end
end
