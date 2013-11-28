module Dap
module Input

  #
  # WARC
  #
  class InputWARC

    include FileSource

    attr_accessor :header, :info

    def initialize(args)
      self.open(args.first)
      read_warc_header
    end

    def read_warc_header
      self.header = read_record
      
      if self.header == Error::EOF
        raise RuntimeError, "Invalid WARC header"
      end

      unless self.header['warc_type'].to_s == "warcinfo"
        raise RuntimeError, "Invalid WARC header (missing warcinfo)"
      end

      self.info = {}
      self.header['content'].to_s.split("\n").each do |line|
        k, v = line.strip.split(/\s*:\s*/, 2)
        next unless v
        self.info[k] = v
      end
    end

    def read_record
      begin

        version = self.fd.readline
        unless version and version =~ /^WARC\/\d+\.\d+/
          return Error::EOF
        end
        warc = {}
      
        loop do
          line = self.fd.readline
          
          unless line.strip.length == 0
            k, v = line.strip.split(/\s*:\s*/, 2)
            k    = k.downcase.gsub('-', '_')
            warc[k] = v.to_s
            next
          end

          unless warc['content_length']
            return Error::EOF
          end

          warc['content'] = self.fd.read(warc['content_length'].to_i)
          skip = self.fd.readline
          skip = self.fd.readline

          unless skip.strip.length == 0
            return Error::EOF
          end

          break
        end

        return warc

      rescue ::EOFError
        return Error::EOF
      end
    end

  end

end
end