module Dap
module Filter

require 'openssl'

#
# Decode LDAP probe response
#
class FilterDecodeLdapResponse
  include BaseDecoder

  def decode_element_length(asn1string)
    # See The BER length section here:
    #    https://blogs.oracle.com/directorymanager/entry/a_quick_introduction_to_asn

    # Length of element starts counting after the sencoded length
    elem_start = 2

    # Unpack the second byte as an integer
    length = asn1string.byteslice(1).unpack('C')[0]

    if length > 127
      # Length will take more than one byte to store
      len_bytes = length - 128
      if asn1string.length > len_bytes + 2
        if len_bytes == 2
          length = asn1string.byteslice(2, len_bytes).unpack('S>')[0]
        else
          length = asn1string.byteslice(2, len_bytes).unpack('L>')[0]
        end
        elem_start += len_bytes
      end
    end

    [elem_start, length]
  end

  def parse_search_result(response)
    # RFC 4511 - Section 4.5.2
    results = {}
    result_type = ''

    if response.value[1].tag == 4
      # SearchResultEntry found..
      result_type = 'SearchResultEntry'
      if response.value[1].value[0].tag == 4
        results['objectName'] = response.value[1].value[0].value
      end

      attrib_hash = {}

      # Handle PartialAttributeValues
      response.value[1].value[1].each do |partial_attrib|

        value_array = []
        attrib_type = partial_attrib.value[0].value

        partial_attrib.value[1].each do |part_attrib_value|
          value_array.push(part_attrib_value.value)
        end

        attrib_hash[attrib_type] = value_array

      end

      results['PartialAttributes'] = attrib_hash

    elsif response.value[1].tag == 5
      # SearchResultDone found..
      result_type = 'SearchResultDone'
      results['resultCode'] = response.value[1].value[0].value.to_i if response.value[1].value[0].value
      results['resultMatchedDN'] = response.value[1].value[1].value if response.value[1].value[1].value
      results['resultdiagMessage'] = response.value[1].value[2].value if response.value[1].value[2].value
    end

    [result_type, results]
  end

  def decode(data)
    # RFC 4511 - 4.5.2 SearchResult contains zero or more SearchResultEntry or
    # SearchResultReference messages followed by a single SearchResultDone
    # message.  OpenSSL::ASN1.decode doesn't handle the back to back Sequences
    # well, so identify the lengths, carve them out, and parse.
    return unless data.length > 2
    pos = 0
    responses = []
    while pos < data.length
      return unless data.byteslice(pos) == '0'
      # Process ASN1 Sequence
      elem_start, elem_len = decode_element_length(data.byteslice(pos..data.length - 1))
      # Calculate element length starting its first byte
      elem_len = elem_start + elem_len
      if data.length >= elem_len + pos
        current_elem = data.byteslice(pos, elem_len)
        responses.push(current_elem)
      end
      pos += elem_len
    end

    info = {}

    responses.each do |element|
      elem_decoded = OpenSSL::ASN1.decode(element) rescue next
      parsed_type, parsed_data = parse_search_result(elem_decoded)
      info[parsed_type] = parsed_data if parsed_data
    end

    info
  end

end

end
end