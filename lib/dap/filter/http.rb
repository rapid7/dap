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
      scan(/<([^<>]{1,4096})>/m).each do |e|

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

  def decode(data)
    lines = data.split(/\r?\n/)
    resp = lines.shift
    save  = {}
    return save if resp !~ /^HTTP\/\d+\.\d+\s+(\d+)(?:\s+(.*))?/

    save["http_code"] = $1.to_i
    save["http_message"] = ($2 ? $2.strip : '')
    save["http_raw_headers"] = {}
    save.merge!(parse_headers(lines))

    head, raw_body = data.split(/\r?\n\r?\n/, 2)

    # Some buggy systems exclude the header entirely
    raw_body ||= head

    save["http_raw_body"] = [raw_body].pack("m*").gsub(/\s+/n, "")
    body = raw_body

    transfer_encoding = save["http_raw_headers"]["transfer-encoding"]
    if transfer_encoding && transfer_encoding.include?("chunked")
      offset = 0
      chunk_num = 1
      body = ''
      while (true)
        # read the chunk size from where we currently are.  The chunk size will
        # be specified in hex, at the beginning, and is followed by \r\n.
        if /^(?<chunk_size_str>[a-z0-9]+)\r\n/i =~ raw_body.slice(offset, raw_body.size)
          # convert chunk size
          chunk_size = chunk_size_str.to_i(16)
          # advance past this chunk marker and its trailing \r\n
          offset += chunk_size_str.size + 2
          if offset + chunk_size > raw_body.size
            $stderr.puts "Skipping impossibly large #{chunk_size}-byte ##{chunk_num} chunk, at offset #{offset}/#{raw_body.size}"
            break
          end
          # read this chunk, starting from just past the chunk marker and
          # stopping at the supposed end of the chunk
          body << raw_body.slice(offset, chunk_size)
          # advance the offset to past the end of the chunk and its trailing \r\n
          offset += chunk_size + 2
          chunk_num += 1
        else
          break
        end
      end

      # chunked-encoding allows headers to occur after the chunks, so parse those
      if offset < raw_body.size
        trailing_headers = parse_headers(raw_body.slice(offset, raw_body.size).split(/\r?\n/))
        save.merge!(trailing_headers) { |header, old, new|
          if old.kind_of?(String)
            [old, new].join(',')
          elsif old.kind_of?(Hash)
            old.merge(new) { |nheader, nold, nnew|
              nold + nnew
            }
          end
        }
      end
    end

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

  def parse_headers(lines)
    headers = {}

    while lines.length > 0
      hline = lines.shift
      if /^(?<header_name>[^:]+):\s*(?<header_value>.*)$/ =~ hline
        header_value.strip!
        header_name.downcase!

        if valid_header_name?(header_name)
          headers["http_raw_headers"] ||= {}
          headers["http_raw_headers"][header_name] ||= []
          headers["http_raw_headers"][header_name] << header_value

          # XXX: warning, all of these mishandle duplicate headers
          case header_name
          when 'etag'
            headers["http_etag"] = header_value

          when 'set-cookie'
            bits = header_value.gsub(/\;?\s*path=.*/i, '').gsub(/\;?\s*expires=.*/i, '').gsub(/\;\s*HttpOnly.*/, '')
            headers["http_cookie"] = bits

          when 'server'
            headers["http_server"] = header_value

          when 'x-powered-by'
            headers["http_powered"] = header_value

          when 'date'
            begin
              d = DateTime.parse(header_value)
              headers["http_date"] = d.to_time.utc.strftime("%Y%m%dT%H:%M:%S%z") if d
            rescue
            end

          when 'last-modified'
            begin
              d = DateTime.parse(header_value)
              headers["http_modified"] = d.to_time.utc.strftime("%Y%m%dT%H:%M:%S%z") if d
            rescue
            end

          when 'location'
            headers["http_location"] = header_value

          when 'www-authenticate'
            headers["http_auth"] = header_value

          when 'content-length'
            headers["content-length"] = header_value.to_i
          end
        else
          # not a valid header.  XXX, eventually we should log or do something more useful here
        end
      elsif hline == ""
        break
      end
    end

    return headers
  end
end
end
end
