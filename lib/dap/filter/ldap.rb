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
    info = {}

    # RFC 4511 - 4.5.2 SearchResult contains zero or more SearchResultEntry or
    # SearchResultReference messages followed by a single SearchResultDone
    # message.  OpenSSL::ASN1.decode doesn't handle the back to back Sequences
    # well, so identify the lengths and split them into individual ASN1 elements
    messages = Dap::Proto::LDAP.split_messages(data)

    if messages.empty?
      err_msg = 'FilterDecodeLdapSearchResult - Unable to parse response'
      info['Error'] = { 'errorMessage' => err_msg }
    end


    messages.each do |element|
      begin
        elem_decoded = OpenSSL::ASN1.decode(element)
      rescue Exception => e
        err_msg = 'FilterDecodeLdapSearchResult - Unable to decode ANS.1 element'
        $stderr.puts "#{err_msg}: #{e}"
        $stderr.puts e.backtrace
        $stderr.puts "\nElement:\n#{element}\n"
        $stderr.puts "\nElement hex:\n#{element.unpack('H*')}\n\n"
        info['Error'] = { 'errorMessage' => err_msg }
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
