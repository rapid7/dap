describe Dap::Filter::FilterDecodeGquicVersionsResult do
  describe '.decode' do

    let(:filter) { described_class.new(['data']) }

    context 'testing gquic valid input' do
      let(:decode) { filter.decode("Q044Q043Q039Q035") }
      it 'returns an hash w/ versions as list of versions' do
        expect(decode).to eq({"versions"=> ["Q044","Q043","Q039","Q035"]})
      end
    end

    context 'testing valid string but not gquic versions' do
      let(:decode) { filter.decode("H044R043E039L035") }
      it 'returns an empty hash' do
        expect(decode).to eq({})
      end
    end

    context 'testing gquic empty string input' do
      let(:decode) { filter.decode("") }
      it 'returns an empty hash' do
        expect(decode).to eq({})
      end
    end

    context 'testing gquic nil input' do
      let(:decode) { filter.decode(nil) }
      it 'returns an empty hash' do
        expect(decode).to eq({})
      end
    end

  end
end
