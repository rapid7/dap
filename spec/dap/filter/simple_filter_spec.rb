describe Dap::Filter::FilterFlatten do
  describe '.process' do

    let(:filter) { described_class.new(["foo"]) }

    context 'flatten nested json' do
      let(:process) { filter.process({"foo" => {"bar" => "baz"}}) }
      it 'has new flattened nested document keys' do
        expect(process).to eq([{"foo" => {"bar" => "baz"}, "foo.bar" => "baz"}])
      end
    end

    context 'ignore unnested keys' do
      let(:process) { filter.process({"foo" => "bar"}) }
      it 'is the same as the original document' do
        expect(process).to eq([{"foo" => "bar"}])
      end
    end
  end
end
