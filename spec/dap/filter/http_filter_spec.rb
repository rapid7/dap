require 'zlib'

describe Dap::Filter::FilterDecodeHTTPReply do
  describe '.decode' do

    let(:filter) { described_class.new(['data']) }


    context 'decoding non-HTTP response' do
      let(:decode) { filter.decode("This\r\nis\r\nnot\r\nHTTP\r\n\r\n") }
      it 'returns an empty hash' do
        expect(decode).to eq({})
      end
    end

    context 'decoding uncompressed response' do
      let(:decode) { filter.decode("HTTP/1.0 200 OK\r\nHeader1: value1\r\nHow(}does<htTp=work?:itdoesn't\r\nHeader2: value2\r\nHEADER2: VALUE2\r\n\r\nstuff") }
      let(:decode_date) { filter.decode("HTTP/1.0 200 OK\r\nHeader1: value1\r\nHow(}does<htTp=work?:itdoesn't\r\nDate: Fri, 24 Mar 2017 15:34:04 GMT\r\nHEADER2: VALUE2\r\nLast-Modified: Fri, 24 Mar 2013 15:34:04 GMT\r\n\r\nstuff") }

      it 'correctly sets status code' do
        expect(decode['http_code']).to eq(200)
      end

      it 'correctly sets status message' do
        expect(decode['http_message']).to eq('OK')
      end

      it 'correctly sets body' do
        expect(decode['http_body']).to eq('stuff')
      end

      it 'correctly extracts http_raw_headers' do
        expect(decode['http_raw_headers']).to eq({'header1' => ['value1'], 'header2' => ['value2', 'VALUE2']})
      end

      it 'extracts Date http header' do
        expect(decode_date['http_raw_headers']['date']).to eq(["Fri, 24 Mar 2017 15:34:04 GMT"])
	expect(decode_date['http_date']).to eq("20170324T15:34:04+0000")
      end

      it 'extracts Last-Modified http header' do
        expect(decode_date['http_raw_headers']['last-modified']).to eq(["Fri, 24 Mar 2013 15:34:04 GMT"])
	expect(decode_date['http_modified']).to eq("20130324T15:34:04+0000")
      end
    end

    context 'decoding gzip compressed response' do
      let(:body) {
        io = StringIO.new
        io.set_encoding('ASCII-8BIT')
        gz = Zlib::GzipWriter.new(io)
        gz.write('stuff')
        gz.close
        io.string
      }
      let(:decode) { filter.decode("HTTP/1.0 200 OK\r\nContent-encoding: gzip\r\n\r\n#{body}") }

      it 'correctly decompresses body' do
        expect(decode['http_body']).to eq('stuff')
      end
    end

  end
end

describe Dap::Filter::FilterHTMLLinks do
  describe '.process' do

    let(:filter) { described_class.new(['data']) }

    context 'lowercase' do
      let(:processed) { filter.process({'data' => '<a href="a"/><a href="b"/>'}) }
      it 'extracted the correct links' do
        expect(processed.map { |p| p['link'] }).to eq(%w(a b))
      end
    end

    context 'uppercase' do
      let(:processed) { filter.process({'data' => '<A HREF="a"/><A HREF="b"/>'}) }
      it 'extracted the correct links' do
        expect(processed.map { |p| p['link'] }).to eq(%w(a b))
      end
    end

    context 'scattercase' do
      let(:processed) { filter.process({'data' => '<A HrEf="a"/><A HrEf="b"/>'}) }
      it 'extracted the correct links' do
        expect(processed.map { |p| p['link'] }).to eq(%w(a b))
      end
    end
  end
end
