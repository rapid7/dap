describe Dap::Filter::FilterDecodeDNSVersionReply do
  describe '.decode' do

    let(:filter) { described_class.new([]) }

    context 'parsing empty string' do
      let(:decode) { filter.decode('') }
      it 'returns an empty hash' do
        expect(decode).to eq( {} )
      end
    end

    base64_string = "AF8074UAAAEAAQABAAAHVkVSU0lPTgRCSU5EAAAQAAPADAAQAAMAAAAAACcmOS44LjJyYzEtUmVkSGF0LTkuOC4yLTAuMzcucmMxLmVsNl83LjXADAACAAMAAAAAAALADA=="
    test_string = base64_string.to_s.unpack('m*').first

    context 'parsing a partial response' do
      let(:decode) { filter.decode(test_string[2..10]) }
      it 'returns an empty hash' do
        expect(decode).to eq( {} )
      end
    end

    context 'parsing TCP DNS response' do
      let(:decode) { filter.decode(test_string) }
      it 'returns the correct version' do
        expect(decode).to eq({ 'dns_version' => '9.8.2rc1-RedHat-9.8.2-0.37.rc1.el6_7.5' })
      end
    end

    # strip the first two bytes from the TCP response to mimic a UDP response
    context 'parsing UDP DNS response' do
      let(:decode) { filter.decode(test_string[2..-1]) }
      it 'returns the correct version' do
        expect(decode).to eq({ 'dns_version' => '9.8.2rc1-RedHat-9.8.2-0.37.rc1.el6_7.5' })
      end
    end

  end
end
