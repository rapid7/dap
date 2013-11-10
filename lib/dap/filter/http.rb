module Dap
module Filter

require 'htmlentities'

class FilterHTMLIframes
  include BaseDecoder

  def extract(doc, field)
    @coder ||= HTMLEntities.new
    data = doc[field]
    urls = []
    data.scan(/<iframe[^>]+/n).each do |frame|
      if frame =~ /src\s*=\s*['"]?\s*([^\s'">$]+)/n
        url = $1.encode!( 'UTF-8', invalid: :replace, undef: :replace, replace: '')
        urls << @coder.decode(url).gsub(/[\x00-\x1f]/n, '')
      end
    end
    urls
  end
end


class FilterDecodeHTTPResponse
  include BaseDecoder

  # TODO: Decode transfer-chunked responses
  def decode(doc, field)
    data  = doc[field]
    lines = data.split(/\r?\n/)
    resp  = lines.shift
    save  = {}
    return save if resp !~ /^HTTP\/\d+\.\d+\s+(\d+)\s+(.*)/

    save["http_code"] = $1.to_i
    save["http_message"] = $2.strip

    clen = nil

    while lines.length > 0
      hline = lines.shift
      case hline
      when /^ETag:\s*(.*)/i
        save["http_etag"] = $1

      when /^Set-Cookie:\s*(.*)/i
        bits = $1.gsub(/\;?\s*path=.*/i, '').gsub(/\;?\s*expires=.*/i, '').gsub(/\;\s*HttpOnly.*/, '')
        save["http_cookie"] = bits.strip

      when /^Server:\s*(.*)/i
        save["http_server"] = $1.strip

      when /^X-Powered-By:\s*(.*)/i
        save["http_powered"] = $1.strip

      when /^Date:\s*(.*)/i
        d = DateTime.parse($1.strip) rescue nil
        save["http_date"] = d if d
          
      when /^Last-modified:\s*(.*)/i
        d = DateTime.parse($1.strip) rescue nil
        save["http_modified"] = d if d

      when /^Location:\s*(.*)/i
        save["http_location"] = $1.strip  
      
      when /^WWW-Authenticate:\s*(.*)/i
        save["http_auth"] = $1.strip

      when /^Content-Length:\s*(.*)/i
        clen = $1.strip.to_i

      when ""
        break
      end
    end

    hidx = data.index(/\r?\n\r?\n/) || 0
    body = data[hidx, data.length-hidx]
    save["http_body"] = body

    if body =~ /<title>([^>]+)</min
      save["http_title"] = $1.strip
    end

    save
  end
end

end
end