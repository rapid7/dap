describe Dap::Filter::FilterCopy do
  describe '.process' do

    let(:filter) { described_class.new(["foo=bar"]) }

    context 'copy one json field to another' do
      let(:process) { filter.process({"foo" => "bar"}) }
      it 'copies and leaves the original field' do
        expect(process).to eq([{"foo" => "bar", "bar" => "bar"}])
      end
    end
  end
end

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

describe Dap::Filter::FilterExpand do
  describe '.process' do

    let(:filter) { described_class.new(["foo"]) }

    context 'expand unnested json' do
      let(:process) { filter.process({"foo.bar" => "baz"}) }
      it 'has new expanded keys' do
        expect(process).to eq([{"foo" => {"bar" => "baz"}, "foo.bar" => "baz"}])
      end
    end

    context 'ignore all but specified  unnested json' do
      let(:process) { filter.process({"foo.bar" => "baz", "baf.blah" => "baz" }) }
      it 'has new expanded keys' do
        expect(process).to eq([{"foo" => {"bar" => "baz"}, "foo.bar" => "baz", "baf.blah" => "baz"}])
      end
    end

    context 'ignore nested json' do
      let(:process) { filter.process({"foo" => "bar"}) }
      it 'is the same as the original document' do
        expect(process).to eq([{"foo" => "bar"}])
      end
    end
  end
end

describe Dap::Filter::FilterTransform do
  describe '.process' do

    let(:filter) { described_class.new(['foo=reverse']) }

    context 'ASCII' do
      let(:process) { filter.process({'foo' => 'abc123'}) }
      it 'is reversed' do
        expect(process).to eq(['foo' => '321cba'])
      end
    end

    context 'UTF-8' do
      let(:process) { filter.process({'foo' => '☹☠'}) }
      it 'is reversed' do
        expect(process).to eq(['foo' => '☠☹'])
      end
    end
  end
end
