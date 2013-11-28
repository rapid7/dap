module Dap
module Filter

require 'htmlentities'
require 'nokogiri'
require 'uri'

class FilterHTMLIframes
  include Base

  def process(doc)
    out = []
    self.opts.each_pair do |k,v|
      next unless doc.has_key?(k)
      extract(doc[k]).each do |url|
        out << doc.merge({ 'iframe' => url })
      end
    end
   out
  end

  def extract(data)
    @coder ||= HTMLEntities.new
    urls = []

    data = data.encode('UTF-8', invalid: :replace, undef: :replace, replace: '')
    html = Nokogiri::HTML(data) do |conf|
      conf.strict.noent
    end

    html.xpath('//iframe').each do |e|
      url = e['src']
      next unless url
      urls << url
    end

    urls
  end
end


class FilterHTMLLinks
  include Base

  def process(doc)
    out = []
    self.opts.each_pair do |k,v|
      next unless doc.has_key?(k)
      extract(doc[k]).each do |link_info|
        out << doc.merge(link_info)
      end
    end
   out
  end

  def extract(data)
    urls = []

    data = data.encode('UTF-8', invalid: :replace, undef: :replace, replace: '')
    html = Nokogiri::HTML(data) do |conf|
      conf.strict.noent
    end

    html.xpath('//*').each do |e|
      url = e['href'] || e['src']
      next unless url
      urls << { 'link' => url, 'element' => e.name }
    end

    urls
  end
end

class FilterDecodeURI
  include BaseDecoder
  def decode(data)
    save = {}
    uri  = URI.parse(data) rescue nil
    return unless uri

    save["host"] = uri.host if uri.host
    save["port"] = uri.port.to_s if uri.port
    save["path"] = uri.path if uri.path
    save["query"]  = uri.query if uri.query
    save["scheme"] = uri.scheme if uri.scheme
    save["user"] = uri.user if uri.user
    save["password"] = uri.password if uri.password

    save
  end
end


class FilterDecodeHTTPReply
  include BaseDecoder

  # TODO: Decode transfer-chunked responses
  def decode(data)
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

    head, body = data.split(/\r?\n\r?\n/, 2)
    
    # Some buggy systems exclude the header entirely
    body ||= head

    save["http_body"] = body

    if body =~ /<title>([^>]+)</min
      save["http_title"] = $1.strip
    end

    save
  end
end

end
end