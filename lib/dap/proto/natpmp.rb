# -*- coding: binary -*-
module Dap
module Proto
module NATPMP

module ResultCode
  SUCCESS = 0
  UNSUPPORTED_VERSION = 1
  UNAUTHORIZED = 2
  NETWORK_FAILURE = 3
  UNAVAILABLE = 4
  UNSUPPORTED_OPCODE = 5
end

# http://tools.ietf.org/html/rfc6886#page-8
class ExternalAddressResponse < BitStruct
  unsigned :version, 8, 'Version' # should always be 0
  unsigned :opcode, 8, 'opcode' # 0-128 request, 128+ response
  unsigned :result, 16, 'result code' # see Dap::Proto::NATPMP::ResultCode
  unsigned :epoch, 32, 'Time elapsed since port mapping table was initialized or reset'
  octets :external_ip, 32, 'External IPv4 address'
  rest :body, 'Payload' # general empty
end
end
end
end
