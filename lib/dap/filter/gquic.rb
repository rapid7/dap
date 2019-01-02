# Documentation on what the different gquic values are
# https://github.com/quicwg/base-drafts/wiki/QUIC-Versions
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
           return unless data
           # need to skip 9 bytes and assume at least one valid version Q044
           if data.length > 9 + 4 && (data.length - 9) % 4
              versions = []
              i = 9
              step = 4
              while i < data.length 
                 version = data[i..i+4-1]
                 # Versions start with the letter Q followed by number e.g. 001 - 043
                 if version =~ /^Q\d{3}$/
                     versions.push(version)
                 end
                 i = i + step
              end
              if versions.length > 0
                 # examples show versions in descending order, but in case its not reverse sort
                 info = {'versions' => versions.sort.reverse}
                 return info
              end
           end
        end
      end
   end
end
