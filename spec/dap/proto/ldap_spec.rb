require 'openssl'
require_relative '../../../lib/dap/proto/ldap'

module Dap
module Proto
class LDAP

describe Dap::Proto::LDAP do
  subject { described_class }

  describe '.decode_elem_length' do
    context 'testing lengths shorter than 128 bits' do
      data = ['301402'].pack('H*')
      let(:decode_len) { subject.decode_elem_length(data) }
      it 'returns a Fixnum' do
        expect(decode_len.class).to eq(::Fixnum)
      end
      it 'returns value correctly' do
        expect(decode_len).to eq(22)
      end
    end

    context 'testing lengths greater than 128 bits' do
      data = ['308400000bc102010'].pack('H*')
      let(:decode_len) { subject.decode_elem_length(data) }
      it 'returns a Fixnum' do
        expect(decode_len.class).to eq(::Fixnum)
      end
      it 'returns value correctly' do
        expect(decode_len).to eq(3015)
      end
    end

    context 'testing invalid length' do
      data = ['308400000bc1'].pack('H*')
      let(:decode_len) { subject.decode_elem_length(data) }
      it 'returns nil as expected' do
        expect(decode_len).to eq(nil)
      end

    end
  end

  describe '.split_messages' do

    original = ['3030020107642b040030273025040b6f626a656374436c61'\
                '737331160403746f70040f4f70656e4c444150726f6f7444'\
                '5345300c02010765070a010004000400']

    data = original.pack('H*')

    entry = ['3030020107642b040030273025040b6f626a656374436c6173'\
             '7331160403746f70040f4f70656e4c444150726f6f74445345']

    done = ['300c02010765070a010004000400']

    context 'testing full message' do
      let(:split_messages) { subject.split_messages(data) }
      it 'returns Array as expected' do
        expect(split_messages.class).to eq(::Array)
      end

      it 'returns SearchResultEntry value as expected' do
        expect(split_messages[0].unpack('H*')).to eq(entry)
      end

      it 'returns SearchResultDone value as expected' do
        expect(split_messages[1].unpack('H*')).to eq(done)
      end
    end
  end

  describe '.parse_messages' do

    context 'testing SearchResultEntry' do
      hex = ['3030020107642b040030273025040b6f626a656374436c6173'\
             '7331160403746f70040f4f70656e4c444150726f6f74445345']
      data = OpenSSL::ASN1.decode(hex.pack('H*'))

      let(:parse_message) { subject.parse_message(data) }
      it 'returns Array as expected' do
        expect(parse_message.class).to eq(::Array)
      end

      it 'returns SearchResultEntry value as expected' do
        test_val = ['SearchResultEntry', {
                      'objectName' => '',
                      'PartialAttributes' => {
                          'objectClass' => [
                            'top',
                            'OpenLDAProotDSE'
                            ]
                      }
        }]
        expect(parse_message).to eq(test_val)
      end
    end

    context 'testing SearchResultDone' do
      hex = ['300c02010765070a010004000400']
      data = OpenSSL::ASN1.decode(hex.pack('H*'))

      let(:parse_message) { subject.parse_message(data) }
      it 'returns Array as expected' do
        expect(parse_message.class).to eq(::Array)
      end

      it 'returns SearchResultDone value as expected' do
        test_val = ['SearchResultDone', {
                      'resultCode' => 0,
                      'resultMatchedDN' => '',
                      'resultdiagMessage' => ''
        }]
        expect(parse_message).to eq(test_val)
      end
    end

    context 'testing UnhandledTag' do
      hex = ['300c02010767070a010004000400']
      data = OpenSSL::ASN1.decode(hex.pack('H*'))

      let(:parse_message) { subject.parse_message(data) }
      it 'returns Array as expected' do
        expect(parse_message.class).to eq(::Array)
      end

      it 'returns UnhandledTag value as expected' do
        test_val = ['UnhandledTag', { 'tagNumber' => 7 }]
        expect(parse_message).to eq(test_val)
      end
    end

  end

end

end
end
end
