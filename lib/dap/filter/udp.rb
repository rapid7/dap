module Dap
module Filter

require 'openssl'
require 'net/dns'
require 'bit-struct'

require 'dap/proto/addp'
require 'dap/proto/dtls'
require 'dap/proto/natpmp'
require 'dap/proto/wdbrpc'
require 'dap/proto/ipmi'
require 'dap/utils/oui'

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
    buff = data.dup

    info = {}
    head = buff.slice!(0,36)
    return info unless head.to_s.length == 36
    return unless buff.length > 0
    info['agent_ver'] = Dap::Proto::WDBRPC.wdbrpc_decode_str(buff)
    info['agent_mtu'] = Dap::Proto::WDBRPC.wdbrpc_decode_int(buff)
    info['agent_mod'] = Dap::Proto::WDBRPC.wdbrpc_decode_int(buff)
    info['rt_type']          = Dap::Proto::WDBRPC.wdbrpc_decode_int(buff)
    info['rt_vers']          = Dap::Proto::WDBRPC.wdbrpc_decode_str(buff)
    info['rt_cpu_type']      = Dap::Proto::WDBRPC.wdbrpc_decode_int(buff)
    info['rt_has_fpp']       = Dap::Proto::WDBRPC.wdbrpc_decode_bool(buff)
    info['rt_has_wp']        = Dap::Proto::WDBRPC.wdbrpc_decode_bool(buff)
    info['rt_page_size']     = Dap::Proto::WDBRPC.wdbrpc_decode_int(buff)
    info['rt_endian']        = Dap::Proto::WDBRPC.wdbrpc_decode_int(buff)
    info['rt_bsp_name']      = Dap::Proto::WDBRPC.wdbrpc_decode_str(buff)
    info['rt_bootline']      = Dap::Proto::WDBRPC.wdbrpc_decode_str(buff)
    info['rt_membase']       = Dap::Proto::WDBRPC.wdbrpc_decode_int(buff)
    info['rt_memsize']       = Dap::Proto::WDBRPC.wdbrpc_decode_int(buff)
    info['rt_region_count']  = Dap::Proto::WDBRPC.wdbrpc_decode_int(buff)
    info['rt_regions']       = Dap::Proto::WDBRPC.wdbrpc_decode_arr(buff, :int)
    info['rt_hostpool_base'] = Dap::Proto::WDBRPC.wdbrpc_decode_int(buff)
    info['rt_hostpool_size'] = Dap::Proto::WDBRPC.wdbrpc_decode_int(buff)

    if info['rt_regions']
      info['rt_regions'] = info['rt_regions'].map{|x| x.to_s}.join(" ")
    end

    nulls = []
    info.each_pair do |k,v|
      nulls << k if v.nil?
    end

    nulls.each {|k| info.delete(k) }

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
      name = Dap::Utils::Oui.lookup_oui_fullname(address)
      name.split("/").first.strip
    rescue => error
      ''
    end
  end

  def mac_company_name(address)
    begin
      Dap::Utils::Oui.lookup_oui_company_name(address)
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

    return info unless (data and data.length > 0)

    head,body = data.to_s.split(/\r?\n\r?\n/, 2)

    head.split(/\r?\n/).each do |line|
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

    if body and body.length > 0
      info['sip_data'] = body
    end

    info
  end
end

#
# Quickly decode a DTLS message
#
class FilterDecodeDTLS
  include BaseDecoder
  def decode(data)
    return unless data.length >= 13
    info = Dap::Proto::DTLS::RecordLayer.new(data)
    return unless (info && info.valid?)
    {}.tap do |h|
      info.fields.each do |f|
        name = f.name
        h[name] = info.send(name).to_s
      end
    end
  end
end

#
# Decode a BACnet Read Property Multiple reply
#
class FilterDecodeBacnetRPMReply
  include BaseDecoder
  TAG_TYPE_LENGTHS = {
    10 => 4,
    11 => 4,
  }
  def decode(sdata)
    info = {}
    return if sdata.length < 9

    data = sdata.dup

    bacnet_vlc_type, bacnet_vlc_function, bacnet_vlc_length = data.slice!(0,4).unpack("CCn")
    # if this isn't a BACnet/IP (0x81) original unicast NPDU (0x0a), abort
    if bacnet_vlc_type != 0x81 || bacnet_vlc_function != 0x0a
      return info
    else
      info['bacnet_vlc_type'] = bacnet_vlc_type
      info['bacnet_vlc_function'] = bacnet_vlc_function
      info['bacnet_vlc_length'] = bacnet_vlc_length
    end

    # we only know how to decode version 1, so abort if it is anything else
    # but store the version in the event that we want to parse these later
    bacnet_npdu_version, bacnet_npdu_control = data.slice!(0,2).unpack("CC")
    info['bacnet_npdu_version'] = bacnet_npdu_version
    info['bacnet_npdu_control'] = bacnet_npdu_control
    return info if bacnet_npdu_version != 1

    bacnet_apdu_type_flags, bacnet_apdu_invoke_id, bacnet_apdu_service_choice = data.slice!(0,3).unpack("CCC")
    bacnet_apdu_type = bacnet_apdu_type_flags >> 4
    bacnet_apdu_flags = bacnet_apdu_type_flags & 0b00001111
    info['bacnet_apdu_type'] = bacnet_apdu_type
    info['bacnet_apdu_flags'] = bacnet_apdu_flags
    info['bacnet_apdu_invoke_id'] = bacnet_apdu_invoke_id
    info['bacnet_apdu_service_choice'] = bacnet_apdu_service_choice
    return info unless (bacnet_apdu_type == 3 && bacnet_apdu_service_choice == 14)

    return info unless data.size > 5
    # XXX: don't know what to do with this right now
    bacnet_object_id = data.slice!(0,5)
    return info unless data.slice!(0,1).unpack('C').first == 0x1e
    props = {}
    # XXX: I think this is ASN.1, but still need to confirm
    while (true) do
      break if data.size < 2
      property_tag, property_id = data.slice!(0,2).unpack('CC')
      props[property_id] = true
      # slice off the opening tag
      otag = data.slice!(0,1).unpack('C').first
      if otag == 0x5e
        data.slice!(0,5)
        props[property_id] = nil
      else
        # it isn't clear if the length is one byte wide followed by one byte of
        # 0x00 for spacing or if it is two bytes little endian.  Looks like the later.
        # XXX?
        tag_flags = data.slice!(0,1).unpack('C').first
        tag_type = tag_flags >> 4
        if TAG_TYPE_LENGTHS.key?(tag_type)
          puts "Know how to handle property #{property_id}'s tag type #{tag_type}"
          props[property_id] = data.slice!(0, TAG_TYPE_LENGTHS[tag_type])
        else
          if tag_type == 7
            property_length = data.slice!(0,2).unpack('v').first
            puts "Handled property #{property_id}'s tag type #{tag_type}"
              property_length -= 1
              # handle String
              props[property_id] = data.slice!(0, property_length)
          else
            puts "Don't know how to handle property #{property_id}'s tag type #{tag_type}"
          end
        end

        ctag = data.slice!(0,1).unpack('C')
      end
      break if data.size == 0
    end

    props.each do |k,v|
      info[k] = v
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
        return info if data.size < 4
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
#
  class FilterDecodePortmapperReply
    include BaseDecoder
    ID_TO_PROTOCOL = {
        0=>"ip",           1=>"icmp",        2=>"igmp",              3=>"ggp",
        4=>"ipencap",      5=>"st",          6=>"tcp",               8=>"egp",
        9=>"igp",          12=>"pup",        17=>"udp",              20=>"hmp",
        22=>"xns-idp",     27=>"rdp",        29=>"iso-tp4",          33=>"dccp",
        36=>"xtp",         37=>"ddp",        38=>"idpr-cmtp",        41=>"ipv6",
        43=>"ipv6-route",  44=>"ipv6-frag",  45=>"idrp",             46=>"rsvp",
        47=>"gre",         50=>"esp",        51=>"ah",               57=>"skip",
        58=>"ipv6-icmp",   59=>"ipv6-nonxt", 60=>"ipv6-opts",        73=>"rspf",
        81=>"vmtp",        88=>"eigrp",      89=>"ospf",             93=>"ax.25",
        94=>"ipip",        97=>"etherip",    98=>"encap",            103=>"pim",
        108=>"ipcomp",     112=>"vrrp",      115=>"l2tp",            124=>"isis",
        132=>"sctp",       133=>"fc",        135=>"mobility-header", 136=>"udplite",
        137=>"mpls-in-ip", 138=>"manet",     139=>"hip",             140=>"shim6",
        141=>"wesp",       142=>"rohc"
    }
    # returns array of program-version-protocol-port strings for each rpc service
    def parse_data(data)
      ret = []
      # Skip past header that contains no rpc services
      stripped = data[8..-1]
      curr_pos = 0
      has_next = ( !stripped.nil? && stripped.length >= 8 ? stripped[curr_pos,8].to_i(16) : 0 )
      curr_pos +=8
      while has_next > 0
        # See if enough data present for next set of reads.
        if data.length > curr_pos+40
          prog_id = stripped[curr_pos,8].to_i(16); curr_pos+=8
          version = stripped[curr_pos,8].to_i(16); curr_pos += 8
          proto_id = stripped[curr_pos,8].to_i(16); curr_pos+=8
          protocol = ID_TO_PROTOCOL[ proto_id ] || "proto-#{proto_id}"
          port = stripped[curr_pos,8].to_i(16); curr_pos += 8
          ret << "#{prog_id}-v#{version}-#{protocol}-#{port}" if prog_id > 0
          has_next = stripped[curr_pos,8].to_i(16); curr_pos += 8
        else
          break
        end
      end
      ret
    end

    def decode(data)
      { 'rpc_services'=>parse_data(data).join(' ') }
    end
  end

end
end
