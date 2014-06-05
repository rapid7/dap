# -*- coding: binary -*-
module Dap
module Proto
module DTLS


class RecordLayer < BitStruct
  unsigned :content_type, 8, 'Content type'
  unsigned :version, 16, 'Version'
  unsigned :epoch, 16, 'Epoch'
  unsigned :sequence, 48, 'Sequence number'
  unsigned :payload_length, 16, 'Payload length'
  rest :payload

  def valid?
    payload_length == payload.length
  end
end
end
end
end
