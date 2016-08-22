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
      let(:decode) { filter.decode("HTTP/1.0 200 OK\r\nHeader1: value1\r\n\r\nstuff") }

      it 'correctly sets status code' do
        expect(decode['http_code']).to eq(200)
      end

      it 'correctly sets status message' do
        expect(decode['http_message']).to eq('OK')
      end

      it 'correctly sets body' do
        expect(decode['http_body']).to eq('stuff')
      end

      it 'correct extracts header(s)' do
        expect(decode['http_raw_headers']).to eq({'header1' => 'value1'})
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
