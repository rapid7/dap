module Dap
   module Filter

      #
      # Decode an Quic VersionsRequest probe response
      #
      class FilterDecodeQuicVersionsResult
        include BaseDecoder

        #
        # Decode an QUIC versions probe response
        #
        # @param data [String] Binary string containing raw response from server
        # @return [List] Hash containing all LDAP responses
        #
        def decode(data)
           # need to skip 9 bytes and assume at least one valid version Q044
           if data.length > 9 + 4 and (data.length - 9) % 4
              versions = []
              i = 9
              step = 4
              while i < data.length 
                 version = data[i..i+4-1]
                 # Versions start with the letter Q
                 if data[i] == 'Q'
                    versions.push(version)
                 end
                 i = i + step
              end
              if versions.length > 0
                 info = {'versions' => versions}
                 info
              end
           end
        end
      end
   end
end
