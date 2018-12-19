require "base64"

describe Dap::Filter::FilterDecodeGquicVersionsResult do
  describe '.decode' do

    let(:filter) { described_class.new(['data']) }

    context 'testing gquic valid input base64 encoded output from the real world' do
      let(:decode) { filter.decode(Base64.decode64("DQAAAAECAwQFUTA0NFEwNDNRMDM5UTAzNQ=="))}
      it 'returns an hash w/ versions as list of versions' do
        expect(decode).to eq({"versions"=> ["Q044","Q043","Q039","Q035"]})
      end
    end

    context 'testing gquic valid input artifical example' do
      let(:decode) { filter.decode("aaaaaaaaaQ044Q043Q039Q035")}
      it 'returns an hash w/ versions as list of versions' do
        expect(decode).to eq({"versions"=> ["Q044","Q043","Q039","Q035"]})
      end
    end

    context 'testing gquic valid versions with invalid versions' do
      let(:decode) { filter.decode("aaaaaaaaaQ044R043R039Q035")}
      it 'returns an hash w/ versions as list of versions' do
        expect(decode).to eq({"versions"=> ["Q044", "Q035"]})
      end
    end

    context 'testing valid string but not gquic versions' do
      let(:decode) { filter.decode("H044R043E039L035") }
      it 'returns nil' do
        expect(decode).to eq(nil)
      end
    end

    # do not want ["Qy6j","Qrta","Ql3T","QkKf","QTUB"]
    context 'testing valid string with Q in it but not gquic versions ' do
      let(:decode) { filter.decode("aaaaaaaaaQy6jQrtaQl3TQkKfQTUB") }
      it 'returns nil' do
        expect(decode).to eq(nil)
      end
    end

    context 'testing gquic empty string input' do
      let(:decode) { filter.decode("") }
      it 'returns nil' do
        expect(decode).to eq(nil)
      end
    end

    context 'testing gquic nil input' do
      let(:decode) { filter.decode(nil) }
      it 'returns nil' do
        expect(decode).to eq(nil)
      end
    end

  end
end
