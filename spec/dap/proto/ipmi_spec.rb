describe Dap::Proto::IPMI::Channel_Auth_Reply do
  describe '.valid?' do

    context 'testing with valid rmcp version and message length' do
      it 'returns true as expected' do
        expect(described_class.new(rmcp_version: 6).valid?).to be false
        expect(described_class.new(message_length: 16).valid?).to be false
        expect(described_class.new(rmcp_version: 6, message_length: 16).valid?).to be true
      end
    end

    context 'testing with invalid data' do
      let(:reply) { described_class.new }

      it 'returns false as expected' do
        expect(reply.valid?).to be false
      end
    end
  end
end
