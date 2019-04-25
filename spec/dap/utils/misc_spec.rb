describe Dap::Utils::Misc do
  context 'flatten_hash' do
    let(:test_hash) { {"foo0": "bar0", "foo1": {"bar1": "stuff", "more": 1}, "foo2": {"bar2": "stuff", "more": 1, "morestuff": {"foo1": "thing1"}}} }
    let(:expected_flat) { {'foo0'=>'bar0', 'foo1.bar1'=>'stuff', 'foo1.more'=>'1', 'foo2.bar2'=>'stuff', 'foo2.more'=>'1', 'foo2.morestuff.foo1'=>'thing1'} }
    let(:actual_flat) { Dap::Utils::Misc.flatten_hash(test_hash) }
    it 'flattens properly' do
      expect(actual_flat).to eq(expected_flat)
    end
  end
end
