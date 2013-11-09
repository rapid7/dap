module Dap
module Filter

require 'htmlentities'

class FilterHTTPDecode
  include Base
  def process(doc)
    self.opts.each_pair do |k,v|
      if doc.has_key?(k)
        doc = doc.merge(decode(doc, k))
      end
    end
   [ doc ]
  end

  # TODO: Decode transfer-chunked responses
  def decode(doc, field)
    data  = doc[field]
    lines = data.split(/\r?\n/)
    resp  = lines.shift
    save  = {}
    return save if resp !~ /^HTTP\/\d+\.\d+\s+(\d+)\s+(.*)/

    save["#{field}.http_code"] = $1.to_i
    save["#{field}.http_message"] = $2.strip

    clen = nil

    while lines.length > 0
      hline = lines.shift
      case hline
      when /^ETag:\s*(.*)/i
        save["#{field}.http_etag"] = $1

      when /^Set-Cookie:\s*(.*)/i
        bits = $1.gsub(/\;?\s*path=.*/i, '').gsub(/\;?\s*expires=.*/i, '').gsub(/\;\s*HttpOnly.*/, '')
        save["#{field}.http_cookie"] = bits.strip

      when /^Server:\s*(.*)/i
        save["#{field}.http_server"] = $1.strip

      when /^X-Powered-By:\s*(.*)/i
        save["#{field}.http_powered"] = $1.strip

      when /^Date:\s*(.*)/i
        d = DateTime.parse($1.strip) rescue nil
        save["#{field}.http_date"] = d if d
          
      when /^Last-modified:\s*(.*)/i
        d = DateTime.parse($1.strip) rescue nil
        save["#{field}.http_modified"] = d if d

      when /^Location:\s*(.*)/i
        save["#{field}.http_location"] = $1.strip  
      
      when /^WWW-Authenticate:\s*(.*)/i
        save["#{field}.http_auth"] = $1.strip

      when /^Content-Length:\s*(.*)/i
        clen = $1.strip.to_i

      when ""
        break
      end
    end

    hidx = data.index(/\r?\n\r?\n/) || 0
    body = data[hidx, data.length-hidx]
    save["#{field}.http_body"] = body

    if body =~ /<title>([^>]+)</min
      save["#{field}.http_title"] = $1.strip
    end

    save
  end
end

class FilterHTMLIframes
  include Base
  def process(doc)
    out = []
    self.opts.each_pair do |k,v|
      if doc.has_key?(k)
        extract(doc, k).each do |url|
          out << doc.merge({ "#{k}.iframe" => url })
        end
      end
    end
    out    
  end

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


end
end