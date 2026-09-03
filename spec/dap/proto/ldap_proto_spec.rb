describe Dap::Proto::LDAP do
  subject { described_class }

  describe '.decode_elem_length' do
    context 'testing lengths shorter than 128 bits' do
      data = ['301402'].pack('H*')

      let(:decode_len) { subject.decode_elem_length(data) }
      it 'returns a Fixnum' do
        expect(decode_len.class).to eq(::Integer)
      end
      it 'returns value correctly' do
        expect(decode_len).to eq(22)
      end
    end

    context 'testing lengths greater than 128 bits' do
      data = ['308400000bc102010'].pack('H*')

      let(:decode_len) { subject.decode_elem_length(data) }
      it 'returns a Fixnum' do
        expect(decode_len.class).to eq(::Integer)
      end
      it 'returns value correctly' do
        expect(decode_len).to eq(3015)
      end
    end

    context 'testing with 3 byte length' do
      data = ['3083015e0802010764'].pack('H*')

      let(:decode_len) { subject.decode_elem_length(data) }
      it 'returns a Fixnum' do
        expect(decode_len.class).to eq(::Integer)
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

    context 'testing empty ASN.1 Sequence' do
      hex = ['308400000000']
      empty_seq = hex.pack('H*')

      let(:split_messages) { subject.split_messages(empty_seq) }
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

    context 'testing SearchResultDone containing a referral' do
      # A referral is a SEQUENCE OF LDAPURL (RFC 4511 - 4.1.10), so the
      # CONTEXT_SPECIFIC element is constructed and decodes to an Array of
      # nested OctetStrings rather than to a String. Modelled on a response
      # observed in the wild, with the host details replaced by documentation
      # addresses; that server also returned success alongside the referral.
      hex = ['3081ca0201076581c40a010004000400a381ba042e6c6461703a2f2f3139322e' \
             '302e322e313a313338392f636e3d7265662c64633d6578616d706c652c64633d' \
             '636f6d04306c6461703a2f2f3139322e302e322e313a31303338392f636e3d72' \
             '6566322c64633d6578616d706c652c64633d636f6d041e6e6c6461703a2f2f31' \
             '39322e302e322e313a3338392f636e3d6e6c64617004186c6461703a2f2f3132' \
             '372e302e302e312f636e3d6c6f6f70041c6c646170733a2f2f3139322e302e32' \
             '2e313a3633362f636e3d73736c']
      data = OpenSSL::ASN1.decode(hex.pack('H*'))

      let(:parse_ldapresult) { subject.parse_ldapresult(data.value[1]) }
      it 'returns Hash as expected' do
        expect(parse_ldapresult.class).to eq(::Hash)
      end

      it 'returns the referral URLs as Strings' do
        test_val = {  'resultCode' => 0,
                      'resultDesc' => 'success',
                      'resultMatchedDN' => '',
                      'resultdiagMessage' => '',
                      'referral' => [
                        'ldap://192.0.2.1:1389/cn=ref,dc=example,dc=com',
                        'ldap://192.0.2.1:10389/cn=ref2,dc=example,dc=com',
                        'nldap://192.0.2.1:389/cn=nldap',
                        'ldap://127.0.0.1/cn=loop',
                        'ldaps://192.0.2.1:636/cn=ssl'
                      ]
        }
        expect(parse_ldapresult).to eq(test_val)
      end

      it 'returns values that can be serialized to JSON' do
        expect { Oj.dump(parse_ldapresult, mode: :strict) }.to_not raise_error
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

  describe 'constructed OCTET STRING in text fields' do

    # matchedDN sent as a constructed OCTET STRING. Every value the parser
    # returns has to survive Oj strict mode, since the JSON output filter runs
    # outside the rescue in FilterDecodeLdapSearchResult and an unserializable
    # value therefore aborts the whole stream rather than one record.
    context 'testing a constructed matchedDN' do
      let(:parsed) do
        done = OpenSSL::ASN1::ASN1Data.new(
          [OpenSSL::ASN1::Enumerated.new(0),
           OpenSSL::ASN1::ASN1Data.new([OpenSSL::ASN1::OctetString.new('dc=a'),
                                        OpenSSL::ASN1::OctetString.new('dc=b')],
                                       4, :UNIVERSAL),
           OpenSSL::ASN1::OctetString.new('')], 5, :APPLICATION)
        der = OpenSSL::ASN1::Sequence.new([OpenSSL::ASN1::Integer.new(7), done]).to_der
        subject.parse_ldapresult(OpenSSL::ASN1.decode(der).value[1])
      end

      it 'returns matchedDN as a concatenated String' do
        expect(parsed['resultMatchedDN']).to eq('dc=adc=b')
      end

      it 'returns a result that can be serialized to JSON' do
        expect { Oj.dump(parsed, mode: :strict) }.to_not raise_error
      end
    end

    context 'testing a constructed attribute type, used as a Hash key' do
      let(:parsed) do
        partial = OpenSSL::ASN1::Sequence.new([
          OpenSSL::ASN1::ASN1Data.new([OpenSSL::ASN1::OctetString.new('object'),
                                       OpenSSL::ASN1::OctetString.new('Class')],
                                      4, :UNIVERSAL),
          OpenSSL::ASN1::Set.new([OpenSSL::ASN1::OctetString.new('top')])])
        entry = OpenSSL::ASN1::ASN1Data.new(
          [OpenSSL::ASN1::OctetString.new('dc=example'),
           OpenSSL::ASN1::Sequence.new([partial])], 4, :APPLICATION)
        der = OpenSSL::ASN1::Sequence.new([OpenSSL::ASN1::Integer.new(7), entry]).to_der
        subject.parse_message(OpenSSL::ASN1.decode(der)).last
      end

      it 'returns the attribute type as a String key' do
        expect(parsed['PartialAttributes']).to eq({ 'objectClass' => ['top'] })
      end

      it 'returns a result that can be serialized to JSON' do
        expect { Oj.dump(parsed, mode: :strict) }.to_not raise_error
      end
    end

  end

  describe '.asn1_value' do

    context 'testing primitive values' do
      it 'passes Strings through unchanged' do
        expect(subject.asn1_value('ldap://192.0.2.1/')).to eq('ldap://192.0.2.1/')
      end

      it 'unwraps a primitive ASN.1 element to its String value' do
        expect(subject.asn1_value(OpenSSL::ASN1::OctetString.new('abc'))).to eq('abc')
      end
    end

    context 'testing values that are not JSON native' do
      # A decoded INTEGER or ENUMERATED yields an OpenSSL::BN, which Oj cannot
      # dump in strict mode any more than it can dump an OctetString. Note that
      # these must be round-tripped through DER: an element built in Ruby holds
      # the Integer it was given, whereas a decoded one holds a BN, and only the
      # latter is what reaches the parser in practice.
      let(:decoded_integer) do
        OpenSSL::ASN1.decode(OpenSSL::ASN1::Integer.new(42).to_der)
      end

      it 'yields an OpenSSL::BN when decoded, which Oj strict mode rejects' do
        expect(decoded_integer.value.class).to eq(OpenSSL::BN)
        expect { Oj.dump({ 'v' => decoded_integer.value }, mode: :strict) }
          .to raise_error(TypeError)
      end

      it 'coerces an OpenSSL::BN to a String' do
        expect(subject.asn1_value(decoded_integer)).to eq('42')
      end

      it 'coerces values nested inside a constructed element' do
        elem = OpenSSL::ASN1.decode(
          OpenSSL::ASN1::ASN1Data.new([OpenSSL::ASN1::Integer.new(42)],
                                      3, :CONTEXT_SPECIFIC).to_der)
        expect(subject.asn1_value(elem.value)).to eq(['42'])
        expect { Oj.dump(subject.asn1_value(elem.value), mode: :strict) }.to_not raise_error
      end

      # Every String this parser yields must be mutable: filters such as
      # `transform <field>=utf8encode` call encode! on the value in place.
      it 'returns a mutable String even when to_s yields a frozen one' do
        frozen_to_s = Class.new { def to_s; 'frozen-result'.freeze; end }.new
        expect(subject.asn1_value(frozen_to_s).frozen?).to be false
        expect(subject.asn1_string(frozen_to_s).frozen?).to be false
      end

      it 'preserves scalars that are already JSON native' do
        decoded_bool = OpenSSL::ASN1.decode(OpenSSL::ASN1::Boolean.new(true).to_der)
        expect(subject.asn1_value(decoded_bool)).to eq(true)
      end
    end

    context 'testing deeply nested elements' do
      let(:deeply_nested) do
        node = OpenSSL::ASN1::OctetString.new('x')
        1000.times { node = OpenSSL::ASN1::Sequence.new([node]) }
        node
      end

      it 'does not exhaust the stack' do
        expect { subject.asn1_value(deeply_nested) }.to_not raise_error
      end

      it 'truncates beyond the depth limit and stays serializable' do
        result = subject.asn1_value(deeply_nested)
        expect(result.flatten).to eq([described_class::ASN1_TOO_DEEP])
        expect { Oj.dump(result, mode: :strict) }.to_not raise_error
      end

      # Filters such as `transform <field>=utf8encode` call encode! on the value,
      # which mutates in place, so a shared frozen marker would raise FrozenError.
      it 'returns the marker unfrozen, like every other value' do
        expect(subject.asn1_value(deeply_nested).flatten).to all(satisfy { |v| !v.frozen? })
      end
    end

  end

  # serverSaslCreds, responseName and responseValue are single-valued per
  # RFC 4511, but each is an OCTET STRING or LDAPOID and so may arrive
  # constructed, exactly as matchedDN may.
  describe 'the optional single-valued CONTEXT_SPECIFIC fields' do
    def self.ldap_message(app_tag, optional)
      body = OpenSSL::ASN1::ASN1Data.new(
        [OpenSSL::ASN1::Enumerated.new(0),
         OpenSSL::ASN1::OctetString.new(''),
         OpenSSL::ASN1::OctetString.new('')] + optional, app_tag, :APPLICATION)
      OpenSSL::ASN1.decode(
        OpenSSL::ASN1::Sequence.new([OpenSSL::ASN1::Integer.new(7), body]).to_der)
    end

    def self.split_octets(a, b, tag)
      OpenSSL::ASN1::ASN1Data.new([OpenSSL::ASN1::OctetString.new(a),
                                   OpenSSL::ASN1::OctetString.new(b)],
                                  tag, :CONTEXT_SPECIFIC)
    end

    context 'testing primitive values' do
      data = ldap_message(24, [OpenSSL::ASN1::ASN1Data.new('1.3.6.1', 10, :CONTEXT_SPECIFIC),
                               OpenSSL::ASN1::ASN1Data.new('payload', 11, :CONTEXT_SPECIFIC)])
      let(:parsed) { subject.parse_message(data).last }

      it 'passes responseName and responseValue through unchanged' do
        expect(parsed['responseName']).to eq('1.3.6.1')
        expect(parsed['responseValue']).to eq('payload')
      end
    end

    context 'testing constructed values' do
      data = ldap_message(24, [split_octets('1.3.', '6.1', 10),
                               split_octets('pay', 'load', 11)])
      let(:parsed) { subject.parse_message(data).last }

      it 'concatenates the segments' do
        expect(parsed['responseName']).to eq('1.3.6.1')
        expect(parsed['responseValue']).to eq('payload')
      end

      it 'returns a result that can be serialized to JSON' do
        expect { Oj.dump(parsed, mode: :strict) }.to_not raise_error
      end
    end

    context 'testing a constructed serverSaslCreds' do
      data = ldap_message(1, [split_octets('cre', 'ds', 7)])
      let(:parsed) { subject.parse_message(data).last }

      it 'concatenates the segments and stays serializable' do
        expect(parsed['serverSaslCreds']).to eq('creds')
        expect { Oj.dump(parsed, mode: :strict) }.to_not raise_error
      end
    end
  end

  describe 'binary attribute values' do

    # Sonar's LDAP data routinely carries binary attribute values such as
    # objectSid and objectGUID. Those must survive byte for byte.
    let(:sid) { "\x01\x05\x00\x00\x00\x00\x00\x05\x15\xff\xfe".b }

    let(:parsed) do
      partial = OpenSSL::ASN1::Sequence.new([
        OpenSSL::ASN1::OctetString.new('objectSid'),
        OpenSSL::ASN1::Set.new([OpenSSL::ASN1::OctetString.new(sid)])])
      entry = OpenSSL::ASN1::ASN1Data.new(
        [OpenSSL::ASN1::OctetString.new('dc=example'),
         OpenSSL::ASN1::Sequence.new([partial])], 4, :APPLICATION)
      der = OpenSSL::ASN1::Sequence.new([OpenSSL::ASN1::Integer.new(7), entry]).to_der
      subject.parse_message(OpenSSL::ASN1.decode(der)).last
    end

    it 'preserves the bytes of a binary value exactly' do
      expect(parsed['PartialAttributes']['objectSid']).to eq([sid])
    end

    it 'preserves the encoding of a binary value' do
      expect(parsed['PartialAttributes']['objectSid'].first.encoding)
        .to eq(::Encoding::ASCII_8BIT)
    end

    it 'returns the value unfrozen' do
      expect(parsed['PartialAttributes']['objectSid'].first.frozen?).to be false
    end

  end

  describe '.asn1_string' do

    # BER permits an OCTET STRING to be sent constructed, in which case the
    # segments concatenate to form the value.
    let(:constructed) do
      OpenSSL::ASN1.decode(
        OpenSSL::ASN1::ASN1Data.new([OpenSSL::ASN1::OctetString.new('dc=exa'),
                                     OpenSSL::ASN1::OctetString.new('mple')],
                                    4, :UNIVERSAL).to_der)
    end

    it 'passes a primitive String value through' do
      expect(subject.asn1_string(OpenSSL::ASN1::OctetString.new('dc=example').value))
        .to eq('dc=example')
    end

    it 'concatenates the segments of a constructed OCTET STRING' do
      expect(subject.asn1_string(constructed.value)).to eq('dc=example')
    end

    it 'always returns a String, so the value is usable as a JSON object key' do
      decoded_int = OpenSSL::ASN1.decode(OpenSSL::ASN1::Integer.new(42).to_der)
      expect(subject.asn1_string(decoded_int)).to eq('42')
      expect { Oj.dump({ subject.asn1_string(constructed.value) => 1 }, mode: :strict) }
        .to_not raise_error
    end

  end

  # These two cases are the only ways this parser's output changed shape for
  # input that already serialized successfully. Both arise when a field the RFC
  # declares an LDAPString / LDAPDN arrives as some other type, and in both the
  # field is now reported with the type it is declared to have. Pinned here so
  # the change is explicit rather than incidental.
  describe 'text fields that arrive with a non-String type' do

    context 'testing a BOOLEAN where an LDAPDN is expected' do
      # matchedDN sent as BOOLEAN true
      hex = ['300a020107e10505000101ff']
      let(:parsed) { subject.parse_message(OpenSSL::ASN1.decode(hex.pack('H*'))).last }

      it 'reports the value as a String rather than a JSON boolean' do
        expect(parsed['resultMatchedDN']).to eq('true')
      end

      # TrueClass#to_s returns a frozen literal, and filters such as
      # `transform <field>=utf8encode` mutate values in place.
      it 'returns that String unfrozen' do
        expect(parsed['resultMatchedDN'].frozen?).to be false
      end
    end

    context 'testing an empty constructed value where an LDAPDN is expected' do
      # matchedDN sent as an empty SEQUENCE
      hex = ['300a02010765050a012f3000']
      let(:parsed) { subject.parse_message(OpenSSL::ASN1.decode(hex.pack('H*'))).last }

      it 'reports the value as an empty String rather than an empty Array' do
        expect(parsed['resultMatchedDN']).to eq('')
      end
    end

    context 'testing a referral whose element is not an OCTET STRING' do
      let(:parsed) do
        referral = OpenSSL::ASN1::ASN1Data.new([OpenSSL::ASN1::Boolean.new(true)],
                                               3, :CONTEXT_SPECIFIC)
        done = OpenSSL::ASN1::ASN1Data.new(
          [OpenSSL::ASN1::Enumerated.new(10), OpenSSL::ASN1::OctetString.new(''),
           OpenSSL::ASN1::OctetString.new(''), referral], 5, :APPLICATION)
        der = OpenSSL::ASN1::Sequence.new([OpenSSL::ASN1::Integer.new(7), done]).to_der
        subject.parse_message(OpenSSL::ASN1.decode(der)).last
      end

      it 'keeps the list shape and reports each URI as a String' do
        expect(parsed['referral']).to eq(['true'])
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

      data = OpenSSL::ASN1::Sequence.new([])

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
