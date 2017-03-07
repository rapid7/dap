module Dap
module Filter

require 'htmlentities'
require 'shellwords'
require 'uri'
require 'zlib'
require 'stringio'

# Dirty element extractor, works around memory issues with Nokogiri
module HTMLGhetto
  def extract_elements(data)
    @coder ||= HTMLEntities.new
    res = []
    data.
      to_s.
      encode('UTF-8', invalid: :replace, undef: :replace, replace: '').
      scan(/<([^>]+)>/m).each do |e|

      e = e.first

      # Skip closing tags
      next if e[0,1] == "/"

      # Get the name vs attributes
      name, astr = e.split(/\s+/, 2).map{|x| x.to_s }
      astr ||= ''

      # Skip non-alpha elements
      next unless name =~ /^[a-zA-Z]/

      # Convert newlines to spaces & strip trailing />
      astr = astr.gsub(/\n/, ' ').sub(/\/$/, '')

      o = { name: name }

      begin
       Shellwords.shellwords(astr).each do |attr_str|
          aname, avalue = attr_str.split('=', 2).map{|x| x.to_s.strip }
          avalue = avalue.to_s.gsub(/^\"|"$/, '')
          o[aname.downcase] = @coder.decode(avalue)
        end
      rescue ::Interrupt
        raise $!
      rescue ::Exception
        # If shellwords couldn't parse it, split on space instead
        astr.to_s.split(/\s+/).each do |attr_str|
          aname, avalue = attr_str.split('=', 2).map{|x| x.to_s.strip }
          avalue = avalue.to_s.gsub(/^\"|"$/, '')
          o[aname.downcase] = @coder.decode(avalue)
        end
      end
      res << o
    end

    res
  end
end

class FilterHTMLIframes
  include Base
  include HTMLGhetto

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
    extract_elements(data).select{|x| x[:name] == 'iframe'}.each do |e|
      url = e['src']
      next unless (url && url.length > 0)
      urls << url
    end
    urls
  end
end


class FilterHTMLLinks
  include Base
  include HTMLGhetto

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

    extract_elements(data).each do |e|
      url = e['href'] || e['src']
      next unless (url && url.length > 0)
      urls << { 'link' => url, 'element' => e[:name] }
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
    save["http_raw_headers"] = {}

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
        save["http_date"] = d.to_time.strftime("%Y%m%dT%H:%M:%S") if d

      when /^Last-modified:\s*(.*)/i
        d = DateTime.parse($1.strip) rescue nil
        save["http_modified"] = d.to_time.strftime("%Y%m%dT%H:%M:%S") if d

      when /^Location:\s*(.*)/i
        save["http_location"] = $1.strip

      when /^WWW-Authenticate:\s*(.*)/i
        save["http_auth"] = $1.strip

      when /^Content-Length:\s*(.*)/i
        clen = $1.strip.to_i

      when /^([A-Za-z0-9\-]+):\s*(.*)/i
        save["http_raw_headers"][$1.downcase.strip] = $2.strip

      when ""
        break
      end
    end

    head, body = data.split(/\r?\n\r?\n/, 2)

    # Some buggy systems exclude the header entirely
    body ||= head

    if save["http_raw_headers"]["content-encoding"] == "gzip"
      begin
        gunzip = Zlib::GzipReader.new(StringIO.new(body))
        body = gunzip.read.encode('UTF-8', :invalid=>:replace, :replace=>'?')
        gunzip.close()
      rescue
      end
    end
    save["http_body"] = body

    if body =~ /<title>([^>]+)</mi
      save["http_title"] = $1.strip
    end

    save
  end
end

end
end
