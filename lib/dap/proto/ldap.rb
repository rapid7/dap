module Dap
module Proto
class LDAP


  #
  # Parse ASN1 element and extract the length.
  # See The BER length section here:
  #    https://blogs.oracle.com/directorymanager/entry/a_quick_introduction_to_asn
  #
  # @param data [String] Binary string containing ASN1 element(s)
  # @return [Fixnum] Total length of of the ASN1 element
  #
  def self.decode_elem_length(data)
    return unless data.length > 2

    # Length of element starts counting after the length
    elem_start = 2

    # Unpack the second byte as an integer
    length = data.byteslice(1).unpack('C')[0]

    if length > 127
      # Length will take more than one byte to store
      len_bytes = length - 128
      return unless data.length > len_bytes + 2

      if len_bytes == 2
        length = data.byteslice(2, len_bytes).unpack('S>')[0]
      else
        length = data.byteslice(2, len_bytes).unpack('L>')[0]
      end
      elem_start += len_bytes
    end

    elem_start + length
  end

  #
  # Split binary string into ASN1 elements.
  #
  # @param data [String] Binary string containing raw response from LDAP server
  # @return [Array] Array of binary strings containing ASN1 elements
  #
  def self.split_messages(data)
    return unless data.length > 2
    pos = 0
    messages = []
    while pos < data.length
      return unless data.byteslice(pos) == '0'
      elem_len = Dap::Proto::LDAP.decode_elem_length(data.byteslice(pos..data.length - 1))
      return unless elem_len

      # Sanity check and then carve out the current element
      if data.length >= elem_len + pos
        current_elem = data.byteslice(pos, elem_len)
        messages.push(current_elem)
      end
      pos += elem_len
    end
    messages
  end

  #
  # Parse an LDAP SearchResult entry.
  #
  # @param data [OpenSSL::ASN1::Sequence] LDAP message to parse
  # @return [Array] Array containing
  #   result_type - Message type (SearchResultEntry, SearchResultDone, etc.)
  #   results     - Hash containing nested decoded LDAP response
  #
  def self.parse_message(data)
    # RFC 4511 - Section 4.5.2

    results = {}
    result_type = ''

    unless data.class == OpenSSL::ASN1::Sequence
      result_type = 'Error'
      results['errorMessage'] = 'parse_message: Message is not of type OpenSSL::ASN1::Sequence'
      return [result_type, results]
    end

    if data.value[1].tag == 4
      # SearchResultEntry found..
      result_type = 'SearchResultEntry'
      if data.value[1].value[0].tag == 4
        results['objectName'] = data.value[1].value[0].value
      end

      attrib_hash = {}

      # Handle PartialAttributeValues
      data.value[1].value[1].each do |partial_attrib|

        value_array = []
        attrib_type = partial_attrib.value[0].value

        partial_attrib.value[1].each do |part_attrib_value|
          value_array.push(part_attrib_value.value)
        end

        attrib_hash[attrib_type] = value_array
      end

      results['PartialAttributes'] = attrib_hash

    elsif data.value[1].tag == 5
      # SearchResultDone found..
      result_type = 'SearchResultDone'
      results['resultCode'] = data.value[1].value[0].value.to_i if data.value[1].value[0].value
      results['resultMatchedDN'] = data.value[1].value[1].value if data.value[1].value[1].value
      results['resultdiagMessage'] = data.value[1].value[2].value if data.value[1].value[2].value
    else
      # Unhandled tag
      result_type = 'UnhandledTag'
      results['tagNumber'] = data.value[1].tag.to_i if data.value[1].tag
    end

    [result_type, results]
  end


end

end
end
