module Dap
module Filter
class FilterDecodeLdapSearchResult

require 'openssl'
require 'dap'
require 'dap/filter/base'
require 'dap/filter/ldap'

describe Dap::Filter::FilterDecodeLdapSearchResult do
  describe '.decode' do

    original = ['3030020107642b040030273025040b6f626a656374436c61'\
                '737331160403746f70040f4f70656e4c444150726f6f7444'\
                '5345300c02010765070a010004000400']

    data = original.pack('H*')

    let(:filter) { FilterDecodeLdapSearchResult.new(['data']) }

    context 'testing full ldap response message' do
      let(:decode) { filter.decode(data) }
      it 'returns Hash as expected' do
        expect(decode.class).to eq(::Hash)
      end

      it 'returns expected value' do
        test_val = { 'SearchResultDone' => {
                       'resultCode' => 0,
                       'resultMatchedDN' => '',
                       'resultdiagMessage' => ''
                   },
                     'SearchResultEntry' => {
                       'objectName' => '',
                       'PartialAttributes' => {
                         'objectClass' => ['top', 'OpenLDAProotDSE']
                       }
        } }

        expect(decode).to eq(test_val)
      end
    end

    context 'testing invalid ldap response message' do
      let(:decode) { filter.decode('303030303030') }
      it 'returns error message as expected' do
        test_val = { 'Error' => {
                       'errorMessage' =>
                       'FilterDecodeLdapSearchResult - Unable to parse response' } }
        expect(decode).to eq(test_val)
      end
    end
  end
end

end
end
end
