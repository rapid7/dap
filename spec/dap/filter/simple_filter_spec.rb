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

    context 'ignore all but specified unnested json' do
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

describe Dap::Filter::FilterRenameSubkeyMatch do
  describe '.process' do

    let(:filter) { described_class.new(['foo', '.', '_']) }

    context 'with subkeys' do
      let(:process) { filter.process({"foo" => {"bar.one" => "baz", "bar.two" => "baz"}, "foo.bar" => "baz", "bar" => {"bar.one" => "baz", "bar.two" => "baz"}}) }
      it 'renames keys as expected' do
        expect(process).to eq([{"foo" => {"bar_one" => "baz", "bar_two" => "baz"}, "foo.bar" => "baz", "bar" => {"bar.one" => "baz", "bar.two" => "baz"}}])
      end
    end

    context 'without subkeys' do
      let(:process) { filter.process({"foo" => "bar", "foo.blah" => "blah", "foo.bar" => "baz"}) }
      it 'produces unchanged output without errors' do
        expect(process).to eq([{"foo" => "bar", "foo.blah" => "blah", "foo.bar" => "baz"}])
      end
    end
  end
end

describe Dap::Filter::FilterMatchRemove do
  describe '.process' do

    let(:filter) { described_class.new(["foo."]) }

    context 'with similar keys' do
      let(:process) { filter.process({"foo" => "bar", "foo.blah" => "blah", "foo.bar" => "baz"}) }
      it 'removes the expected keys' do
        expect(process).to eq([{"foo" => "bar"}])
      end
    end
  end
end

describe Dap::Filter::FilterMatchSelect do
  describe '.process' do

    let(:filter) { described_class.new(["foo."]) }

    context 'with similar keys' do
      let(:process) { filter.process({"foo" => "bar", "foo.blah" => "blah", "foo.bar" => "baz"}) }
      it 'selects the expected keys' do
        expect(process).to eq([{"foo.blah" => "blah", "foo.bar" => "baz"}])
      end
    end
  end
end

describe Dap::Filter::FilterSelect do
  describe '.process' do

    let(:filter) { described_class.new(["foo"]) }

    context 'with similar keys' do
      let(:process) { filter.process({"foo" => "bar", "foobar" => "blah"}) }
      it 'selects the expected keys' do
        expect(process).to eq([{"foo" => "bar"}])
      end
    end
  end
end

describe Dap::Filter::FilterMatchSelectKey do
  describe '.process' do

    let(:filter) { described_class.new(["foo."]) }

    context 'with similar keys' do
      let(:process) { filter.process({"foo" => "bar", "foo.blah" => "blah", "foo.bar" => "baz"}) }
      it 'selects the expected keys' do
        expect(process).to eq([{"foo.blah" => "blah", "foo.bar" => "baz"}])
      end
    end
  end
end

describe Dap::Filter::FilterMatchSelectValue do
  describe '.process' do

    let(:filter) { described_class.new(["ba"]) }

    context 'with similar keys' do
      let(:process) { filter.process({"foo" => "bar", "foo.blah" => "blah", "foo.bar" => "baz"}) }
      it 'selects the expected keys' do
        expect(process).to eq([{"foo" => "bar", "foo.bar" => "baz"}])
      end
    end
  end
end

describe Dap::Filter::FilterTransform do
  describe '.process' do

    context 'invalid transform' do
      let(:filter) { described_class.new(['foo=blahblah']) }
      it 'fails' do
        expect { filter.process({'foo' => 'abc123'}) }.to raise_error(RuntimeError, /Invalid transform/)
      end
    end

    context 'reverse' do
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

    context 'int default' do
      let(:filter) { described_class.new(['val=int']) }

      context 'valid int' do
        let(:process) { filter.process({'val' => '1'}) }
        it 'is the correct int' do
          expect(process).to eq(['val' => 1])
        end
      end

      context 'invalid int' do
        let(:process) { filter.process({'val' => 'cats'}) }
        it 'is the correct int' do
          expect(process).to eq(['val' => 0])
        end
      end
    end

    context 'int different base' do
      let(:filter) { described_class.new(['val=int16']) }
      let(:process) { filter.process({'val' => 'FF'}) }

      it 'is the correct int' do
        expect(process).to eq(['val' => 255])
      end
    end

    context 'float' do
      let(:filter) { described_class.new(['val=float']) }

      context 'valid float' do
        let(:process) { filter.process({'val' => '1.0'}) }
        it 'is the correct float' do
          expect(process).to eq(['val' => 1.0])
        end
      end

      context 'invalid float' do
        let(:process) { filter.process({'val' => 'cats.0'}) }
        it 'is the correct float' do
          expect(process).to eq(['val' => 0.0])
        end
      end
    end

    context 'json' do
      let(:filter) { described_class.new(['val=json']) }

      context 'valid json' do
        let(:process) { filter.process({'val' => '{"nested": "1"}'}) }
        it 'is the correct JSON' do
          expect(process).to eq(['val' => { 'nested' => '1' }])
        end
      end

      context 'invalid json' do
        it 'raises on invalid JSON' do
          expect { filter.process({'val' => '{abc123'}) }.to raise_error(JSON::ParserError)
        end
      end
    end

    context 'stripping' do
      context 'lstrip' do
        let(:filter) { described_class.new(['foo=lstrip']) }
        let(:process) { filter.process({'foo' => ' abc123  '}) }
        it 'lstripped' do
          expect(process).to eq(['foo' => 'abc123  '])
        end
      end

      context 'rstrip' do
        let(:filter) { described_class.new(['foo=rstrip']) }
        let(:process) { filter.process({'foo' => ' abc123  '}) }
        it 'rstripped' do
          expect(process).to eq(['foo' => ' abc123'])
        end
      end

      context 'strip' do
        let(:filter) { described_class.new(['foo=strip']) }
        let(:process) { filter.process({'foo' => ' abc123  '}) }
        it 'stripped' do
          expect(process).to eq(['foo' => 'abc123'])
        end
      end
    end
  end
end

describe Dap::Filter::FilterFieldReplace do
  describe '.process' do

    let(:filter) { described_class.new(["value1=foo=bar"]) }

    let(:process) { filter.process({"value1" => "foo.bar.foo", "value2" => "secret"}) }
    it 'replaced correctly' do
      expect(process).to eq([{"value1" => "bar.bar.foo", "value2" => "secret"}])
    end
  end
end

describe Dap::Filter::FilterFieldReplaceAll do
  describe '.process' do

    let(:filter) { described_class.new(["value1=foo=bar"]) }

    let(:process) { filter.process({"value1" => "foo.bar.foo", "value2" => "secret"}) }
    it 'replaced correctly' do
      expect(process).to eq([{"value1" => "bar.bar.bar", "value2" => "secret"}])
    end
  end
end

describe Dap::Filter::FilterFieldSplitPeriod do
  describe '.process' do

    let(:filter) { described_class.new(["value"]) }

    context 'splitting on period boundary' do
      let(:process) { filter.process({"value" => "foo.bar.baf"}) }
      it 'splits correctly' do
        expect(process).to eq([{"value" => "foo.bar.baf", "value.f1" => "foo", "value.f2" => "bar", "value.f3" => "baf"}])
      end
    end
  end
end

describe Dap::Filter::FilterFieldSplitLine do
  describe '.process' do

    let(:filter) { described_class.new(["value"]) }

    context 'splitting on newline boundary' do
      let(:process) { filter.process({"value" => "foo\nbar\nbaf"}) }
      it 'splits correctly' do
        expect(process).to eq([{"value" => "foo\nbar\nbaf", "value.f1" => "foo", "value.f2" => "bar", "value.f3" => "baf"}])
      end
    end
  end
end
