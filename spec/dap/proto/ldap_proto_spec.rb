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

    context 'testing with 3 byte length' do
      data = ['3083015e0802010764'].pack('H*')

      let(:decode_len) { subject.decode_elem_length(data) }
      it 'returns a Fixnum' do
        expect(decode_len.class).to eq(::Fixnum)
      end
      it 'returns value correctly' do
        expect(decode_len).to eq(89613)
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

    excessive_len = ['308480010000000000000000'].pack('H*')

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

    context 'testing invalid message' do
      let(:split_messages) { subject.split_messages('FF') }
      it 'returns Array as expected' do
        expect(split_messages.class).to eq(::Array)
      end
    end

    context 'testing short message' do
      let(:split_messages) { subject.split_messages('00') }
      it 'returns Array as expected' do
        expect(split_messages.class).to eq(::Array)
      end
    end

    context 'testing message length greater than total data length' do
      let(:split_messages) { subject.split_messages(excessive_len) }
      it 'returns Array as expected' do
        expect(split_messages.class).to eq(::Array)
      end

      it 'returns empty Array as expected' do
        expect(split_messages).to eq([])
      end
    end
  end

  describe '.parse_ldapresult' do

    context 'testing valid data' do
      hex = ['300c02010765070a010004000400']
      data = OpenSSL::ASN1.decode(hex.pack('H*'))

      let(:parse_ldapresult) { subject.parse_ldapresult(data.value[1]) }
      it 'returns Hash as expected' do
        expect(parse_ldapresult.class).to eq(::Hash)
      end

      it 'returns results as expected' do
        test_val = {  'resultCode' => 0,
                      'resultDesc' => 'success',
                      'resultMatchedDN' => '',
                      'resultdiagMessage' => ''
        }
        expect(parse_ldapresult).to eq(test_val)
      end
    end

    context 'testing invalid data' do
      hex = ['300702010765020400']
      data = OpenSSL::ASN1.decode(hex.pack('H*'))

      let(:parse_ldapresult) { subject.parse_ldapresult(data.value[1]) }
      it 'returns Hash as expected' do
        expect(parse_ldapresult.class).to eq(::Hash)
      end

      it 'returns empty Hash as expected' do
        test_val = {}
        expect(parse_ldapresult).to eq(test_val)
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
                      'resultDesc' => 'success',
                      'resultMatchedDN' => '',
                      'resultdiagMessage' => ''
        }]
        expect(parse_message).to eq(test_val)
      end
    end

    context 'testing SearchResultDone - edge case #1' do
      hex = ['300802010765000a0101']
      data = OpenSSL::ASN1.decode(hex.pack('H*'))

      let(:parse_message) { subject.parse_message(data) }
      it 'returns Array as expected' do
        expect(parse_message.class).to eq(::Array)
      end

      it 'returns operationsError as expected' do
        test_val = ['SearchResultDone', {
                      'resultCode' => 1,
                      'resultDesc' => 'operationsError'
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

    context 'testing empty ASN.1 Sequence' do
      hex = ['308400000000']
      data = OpenSSL::ASN1.decode(hex.pack('H*'))

      let(:parse_message) { subject.parse_message(data) }
      it 'returns Array as expected' do
        expect(parse_message.class).to eq(::Array)
      end

      it 'returns error value as expected' do
        test_val = ['Error', {
                      'errorMessage' =>
                        'parse_message: Invalid LDAP response (Empty Sequence)'
        }]
        expect(parse_message).to eq(test_val)
      end
    end

  end

end
