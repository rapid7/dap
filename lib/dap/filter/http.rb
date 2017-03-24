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
      if /^(?<header_name>[^:]+):\s*(?<header_value>.*)$/ =~ hline
        header_value.strip!
        header_name.downcase!

        if valid_header_name?(header_name)
          save["http_raw_headers"] ||= {}
          save["http_raw_headers"][header_name] ||= []
          save["http_raw_headers"][header_name] << header_value

          # XXX: warning, all of these mishandle duplicate headers
          case header_name
          when 'etag'
            save["http_etag"] = header_value

          when 'set-cookie'
            bits = header_value.gsub(/\;?\s*path=.*/i, '').gsub(/\;?\s*expires=.*/i, '').gsub(/\;\s*HttpOnly.*/, '')
            save["http_cookie"] = bits

          when 'server'
            save["http_server"] = header_value

          when 'x-powered-by'
            save["http_powered"] = header_value

          when 'date'
            d = DateTime.parse(header_value) rescue nil
            save["http_date"] = d.to_time.utc.strftime("%Y%m%dT%H:%M:%S%z") if d

          when 'last-modified'
            d = DateTime.parse(header_value) rescue nil
            save["http_modified"] = d.to_time.utc.strftime("%Y%m%dT%H:%M:%S%z") if d

          when 'location'
            save["http_location"] = header_value

          when 'www-authenticate'
            save["http_auth"] = header_value

          when 'content-length'
            save["content-length"] = header_value.to_i
          end
        else
          # not a valid header.  XXX, eventually we should log or do something more useful here
        end
      elsif hline == ""
        break
      end
    end

    head, body = data.split(/\r?\n\r?\n/, 2)

    # Some buggy systems exclude the header entirely
    body ||= head

    content_encoding = save["http_raw_headers"]["content-encoding"]

    if content_encoding && content_encoding.include?("gzip")
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

  def valid_header_name?(name)
    return name !~ /[\x00-\x1f()<>@,;:\\\"\/\[\]?={}\s]/
  end
end

end
end
