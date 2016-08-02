module Dap
module Proto
class LDAP

  # LDAPResult element resultCode lookup
  #   Reference: https://tools.ietf.org/html/rfc4511#section-4.1.9
  #              https://ldapwiki.willeke.com/wiki/LDAP%20Result%20Codes
  RESULT_DESC = {
    0 => 'success',
    1 => 'operationsError',
    2 => 'protocolError',
    3 => 'timeLimitExceeded',
    4 => 'sizeLimitExceeded',
    5 => 'compareFalse',
    6 => 'compareTrue',
    7 => 'authMethodNotSupported',
    8 => 'strongerAuthRequired',
    9 => 'reserved',
    10 => 'referral',
    11 => 'adminLimitExceeded',
    12 => 'unavailableCriticalExtension',
    13 => 'confidentialityRequired',
    14 => 'saslBindInProgress',
    16 => 'noSuchAttribute',
    17 => 'undefinedAttributeType',
    18 => 'inappropriateMatching',
    19 => 'constraintViolation',
    20 => 'attributeOrValueExists',
    21 => 'invalidAttributeSyntax',
    32 => 'noSuchObject',
    34 => 'invalidDNSyntax',
    48 => 'inappropriateAuthentication',
    49 => 'invalidCredentials',
    50 => 'insufficientAccessRights',
    51 => 'busy',
    52 => 'unavailable',
    53 => 'unwillingToPerform',
    64 => 'namingViolation',
    80 => 'other',
    82 => 'localError (client response)',
    94 => 'noResultsReturned (client response)',
  }

  #
  # Parse ASN1 element and extract the length.
  # See The BER length section here:
  #    https://blogs.oracle.com/directorymanager/entry/a_quick_introduction_to_asn
  #
  # @param data [String] Binary string containing ASN1 element(s)
  # @return [Fixnum, nil] Total length of of the ASN1 element, nil on error
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

      # This shouldn't happen...
      return unless len_bytes > 0

      length = 0
      len_bytes.times do |i|
        temp_len = data.byteslice(2 + i).unpack('C')[0]
        length = ( length << 8 ) + temp_len
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
    messages = []
    return messages unless data.length > 2
    pos = 0
    while pos < data.length
      break unless data.byteslice(pos) == '0'
      elem_len = Dap::Proto::LDAP.decode_elem_length(data.byteslice(pos..data.length - 1))
      break unless elem_len

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
  # Parse an LDAPResult (not SearchResult) ASN.1 structure
  #   Reference:  https://tools.ietf.org/html/rfc4511#section-4.1.9
  #
  # @param data [OpenSSL::ASN1::ASN1Data] LDAPResult structure
  # @return [Hash] Hash containing decoded LDAP response
  #
  def self.parse_ldapresult(ldap_result)
    results = {}

    # Sanity check the result code element
    if ldap_result.value[0] && ldap_result.value[0].value
      code_elem = ldap_result.value[0]
      return results unless code_elem.tag == 10 && code_elem.tag_class == :UNIVERSAL
      results['resultCode'] = code_elem.value.to_i
    end

    # These are probably safe if the resultCode validates
    results['resultDesc'] = RESULT_DESC[ results['resultCode'] ] if results['resultCode']
    results['resultMatchedDN'] = ldap_result.value[1].value if ldap_result.value[1] && ldap_result.value[1].value
    results['resultdiagMessage'] = ldap_result.value[2].value if ldap_result.value[2] && ldap_result.value[2].value

    # Handle optional elements that may be returned by certain
    # LDAP application messages
    ldap_result.value.each do |element|
      next unless element.tag_class && element.tag && element.value
      next unless element.tag_class == :CONTEXT_SPECIFIC

      case element.tag
      when 3
        results['referral'] = element.value
      when 7
        results['serverSaslCreds'] = element.value
      when 10
        results['responseName'] = element.value
      when 11
        results['responseValue'] = element.value
      end
    end

    results
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

    result_type = ''
    results = {}

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

      if data.value[1].value[1]
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
      end

    elsif data.value[1] && data.value[1].tag == 5
      # SearchResultDone found..
      result_type = 'SearchResultDone'
      ldap_result = data.value[1]

      if ldap_result.value[0] && ldap_result.value[0].class == OpenSSL::ASN1::Sequence
        # Encoding of the SearchResultDone seems to vary, this is RFC format
        # of an LDAPResult ASN.1 structure in which the data is contained in a
        # Sequence
        results = parse_ldapresult(ldap_result.value[0])
      elsif ldap_result.value[0]
        # LDAPResult w/o outer Sequence wrapper, used by MS Windows
        results = parse_ldapresult(ldap_result)
      end
      if data.value[2] && data.value[2].tag == 10
        # Unknown structure for providing a response, looks like LDAPResult
        # but placed at a higher level in the response, salvage what we can..
        results['resultCode'] = data.value[2].value.to_i if data.value[2].value
        results['resultDesc'] = RESULT_DESC[ results['resultCode'] ] if results['resultCode']
        results['resultMatchedDN'] = data.value[3].value if data.value[3] && data.value[3].value
        results['resultdiagMessage'] = data.value[4].value if data.value[4] && data.value[4].value
      end

    elsif data.value[1] && data.value[1].tag == 1
      result_type = 'BindResponse'
      results = parse_ldapresult(data.value[1])

    elsif data.value[1] && data.value[1].tag == 2
      result_type = 'UnbindRequest'

    elsif data.value[1] && data.value[1].tag == 3
      # There is no legitimate use of application tag 3
      # in this context per RFC 4511. Try to figure
      # out what the intent is.
      resp_data = data.value[1]
      if resp_data.value[0].tag == 10 && resp_data.value[2].tag == 4
        # Probably an incorrectly tagged BindResponse
        result_type = 'BindResponse'
        results = parse_ldapresult(resp_data)
      else
        result_type = 'UnhandledTag'
        results['tagNumber'] = data.value[1].tag.to_i if data.value[1].tag
      end

    elsif data.value[1] && data.value[1].tag == 24
      result_type = 'ExtendedResponse'
      results = parse_ldapresult(data.value[1])

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
