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

    context 'decoding binary response' do
      # this represents the HTTP response for an HTTP/1.1 request for
      # https://upload.wikimedia.org/wikipedia/commons/c/ca/1x1.png, which you
      # can replicate with something like
      #   echo -n "HTTP/1.1 `lwp-request -sem GET https://upload.wikimedia.org/wikipedia/commons/c/ca/1x1.png`" | base64
      let(:decode) { filter.decode("SFRUUC8xLjEgMjAwIE9LCkNvbm5lY3Rpb246IGNsb3NlCkRhdGU6IFR1ZSwgMjggTWFyIDIwMTcgMTc6MTg6NTQgR01UClZpYTogMS4xIHZhcm5pc2gtdjQsIDEuMSB2YXJuaXNoLXY0LCAxLjEgdmFybmlzaC12NCwgMS4xIHZhcm5pc2gtdjQKQWNjZXB0LVJhbmdlczogYnl0ZXMKQWdlOiAxNDc2MTkKRVRhZzogNzFhNTBkYmJhNDRjNzgxMjhiMjIxYjdkZjdiYjUxZjEKQ29udGVudC1MZW5ndGg6IDk1CkNvbnRlbnQtVHlwZTogaW1hZ2UvcG5nCkxhc3QtTW9kaWZpZWQ6IFN1biwgMDYgT2N0IDIwMTMgMjM6NTQ6MjUgR01UCkFjY2Vzcy1Db250cm9sLUFsbG93LU9yaWdpbjogKgpBY2Nlc3MtQ29udHJvbC1FeHBvc2UtSGVhZGVyczogQWdlLCBEYXRlLCBDb250ZW50LUxlbmd0aCwgQ29udGVudC1SYW5nZSwgWC1Db250ZW50LUR1cmF0aW9uLCBYLUNhY2hlLCBYLVZhcm5pc2gKQ2xpZW50LURhdGU6IFR1ZSwgMjggTWFyIDIwMTcgMTc6MTg6NTQgR01UCkNsaWVudC1QZWVyOiAxOTguMzUuMjYuMTEyOjQ0MwpDbGllbnQtUmVzcG9uc2UtTnVtOiAxCkNsaWVudC1TU0wtQ2VydC1Jc3N1ZXI6IC9DPUJFL089R2xvYmFsU2lnbiBudi1zYS9DTj1HbG9iYWxTaWduIE9yZ2FuaXphdGlvbiBWYWxpZGF0aW9uIENBIC0gU0hBMjU2IC0gRzIKQ2xpZW50LVNTTC1DZXJ0LVN1YmplY3Q6IC9DPVVTL1NUPUNhbGlmb3JuaWEvTD1TYW4gRnJhbmNpc2NvL089V2lraW1lZGlhIEZvdW5kYXRpb24sIEluYy4vQ049Ki53aWtpcGVkaWEub3JnCkNsaWVudC1TU0wtQ2lwaGVyOiBBRVMxMjgtU0hBCkNsaWVudC1TU0wtU29ja2V0LUNsYXNzOiBJTzo6U29ja2V0OjpTU0wKQ2xpZW50LVNTTC1XYXJuaW5nOiBQZWVyIGNlcnRpZmljYXRlIG5vdCB2ZXJpZmllZApTdHJpY3QtVHJhbnNwb3J0LVNlY3VyaXR5OiBtYXgtYWdlPTMxNTM2MDAwOyBpbmNsdWRlU3ViRG9tYWluczsgcHJlbG9hZApUaW1pbmctQWxsb3ctT3JpZ2luOiAqClgtQW5hbHl0aWNzOiBodHRwcz0xO25vY29va2llcz0xClgtQ2FjaGU6IGNwMTA3MSBoaXQvOSwgY3AyMDIwIGhpdC8yLCBjcDQwMDUgbWlzcywgY3A0MDE1IGhpdC84ODg3ClgtQ2FjaGUtU3RhdHVzOiBoaXQKWC1DbGllbnQtSVA6IDE3My4xNy43OS41NApYLU9iamVjdC1NZXRhLVNoYTFiYXNlMzY6IDFxNG5hMXhqNnRvcHpsbjUxdHB6cXF4dGR0ZHdvOXAKWC1UaW1lc3RhbXA6IDEzODExMDM2NjQuMDg2NDMKWC1UcmFucy1JZDogdHgzZDZmMmU1NzQ0MGM0NzA4YTI0ZjgtMDA1OGQ4NWE1YgpYLVZhcm5pc2g6IDYwMTIxMjI1IDU4NDE4ODgsIDQ3NzczOTUyIDM4MjY4MDcwLCA3MDcxNjg5NiwgNDM2MzkyNTAwIDE4MjE4MjgwMwoKiVBORw0KGgoAAAANSUhEUgAAAAEAAAABAQMAAAAl21bKAAAAA1BMVEUAAACnej3aAAAAAXRSTlMAQObYZgAAAApJREFUCNdjYAAAAAIAAeIhvDMAAAAASUVORK5CYII".unpack("m*").first) }

      it 'correctly sets http_raw_body base64' do
        expect(decode['http_raw_body']).to eq('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABAQMAAAAl21bKAAAAA1BMVEUAAACnej3aAAAAAXRSTlMAQObYZgAAAApJREFUCNdjYAAAAAIAAeIhvDMAAAAASUVORK5CYII=')
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

    context 'decoding responses that are missing the "reason phrase", an RFC anomaly' do
      let(:decode) { filter.decode("HTTP/1.1 301\r\nDate: Tue, 28 Mar 2017 20:46:52 GMT\r\nContent-Type: text/html\r\nContent-Length: 177\r\nConnection: close\r\nLocation: http://www.example.com/\r\n\r\nstuff") }

      it 'decodes anyway' do
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
