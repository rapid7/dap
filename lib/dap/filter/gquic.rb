module Dap
   module Filter

      #
      # Decode a Google Quic VersionsRequest probe response
      #
      class FilterDecodeGquicVersionsResult
        include BaseDecoder

        #
        # Decode an GQUIC ( Google Quic) versions probe response
        #
        # @param data [String] Binary string containing raw response from server
        # @return [Hash] containing all GQUIC versions supported else nil
        #
        def decode(data)
           if data.nil?
              return nil
           end
           # need to skip 9 bytes and assume at least one valid version Q044
           if data.length > 9 + 4 && (data.length - 9) % 4
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
                 return info
              end
           end
        end
      end
   end
end
