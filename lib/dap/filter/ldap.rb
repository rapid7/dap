module Dap
module Filter

require 'openssl'

require 'dap/proto/ldap'

#
# Decode an LDAP SearchRequest probe response
#
class FilterDecodeLdapSearchResult
  include BaseDecoder

  #
  # Decode an LDAP SearchRequest probe response
  #
  # @param data [String] Binary string containing raw response from server
  # @return [Hash] Hash containing all LDAP responses
  #
  def decode(data)
    return unless data.length > 2

    # RFC 4511 - 4.5.2 SearchResult contains zero or more SearchResultEntry or
    # SearchResultReference messages followed by a single SearchResultDone
    # message.  OpenSSL::ASN1.decode doesn't handle the back to back Sequences
    # well, so identify the lengths and split them into individual ASN1 elements
    messages = Dap::Proto::LDAP.split_messages(data)
    return unless messages

    info = {}

    messages.each do |element|
      begin
        elem_decoded = OpenSSL::ASN1.decode(element)
      rescue Exception => e
        $stderr.puts "\nError: FilterDecodeLdapSearchResult - Unable to decode ANS1 element"
        $stderr.puts "Error message: #{e.message}"
        $stderr.puts e.backtrace
        next
      end
      parsed_type, parsed_data = Dap::Proto::LDAP.parse_message(elem_decoded)
      info[parsed_type] = parsed_data if parsed_type && parsed_data
    end

    info
  end

end

end
end
