require 'bit-struct'
require_relative '../../../lib/dap/proto/ipmi'

module Dap
module Proto
module IPMI

describe Channel_Auth_Reply do
  it "valid with the proper rmcp version and message length" do
    expect(subject.valid?).to be_false
    expect(Channel_Auth_Reply.new(rmcp_version: 6).valid?).to be_false
    expect(Channel_Auth_Reply.new(message_length: 16).valid?).to be_false
    expect(Channel_Auth_Reply.new(rmcp_version: 6, message_length: 16).valid?).to be_true
  end
end

end
end
end
