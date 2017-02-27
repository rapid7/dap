describe Dap::Input::InputJSON do
  describe '.read_record' do
    context 'decoding input json' do
      let(:file_object) { double("fake file") }
      let(:input) { described_class.new(['data']) }
      let(:record) { input.read_record }
      it 'parses values starting with a colon (:) as a string' do
        allow(File).to receive(:open).with('data', 'rb').and_return(file_object)
        allow(file_object).to receive(:readline).and_return('{"a": ":b"}')
        expect(record['a']).to eq(":b")
      end
    end
  end
end