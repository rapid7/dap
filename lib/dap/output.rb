require 'oj'
require 'csv'


module Dap
module Output


  module FileDestination

    attr_accessor :fd

    def open(file_name)
      close
      self.fd = ['-', 'stdout', nil].include?(file_name) ?
        $stdout : ::File.open(file_name, "wb")
    end

    def close
      self.close if self.fd
      self.fd = nil
    end

    # Overload this to add headers
    def start
    end

    # Overload this to add footers
    def stop
    end

    # String sanitizer for UTF-8
    def sanitize(o)

      # Handle strings
      if o.kind_of? ::String
        return o.to_s.encode(o.encoding, "UTF-8", :invalid => :replace, :undef => :replace, :replace => '')
      end

      # Handle hashes
      if o.kind_of? ::Hash
        r = {}
        o.each_pair do |k,v|
          k = sanitize(k)
          v = sanitize(v)
          r[k] = v
        end
        return r
      end

      # Handle arrays
      if o.kind_of? ::Array
        return o.map{|x| sanitize(x) }
      end

      # Leave as-is
      o
    end
  end


  #
  # Line Output (CSV, TSV, etc)
  # XXX: Quoted field handling is not supported, CSV should be a new output type
  #
  class OutputLines

    attr_accessor :fields, :delimiter
    FIELD_WILDCARD = '_'

    include FileDestination

    def initialize(args)
      file = nil
      self.delimiter = ","
      self.fields    = FIELD_WILDCARD

      header = false

      args.each do |str|
        k,v = str.split('=', 2)
        case k
        when 'file'
          file = v
        when 'header'
          header = ( v =~ /^[ty1]/i ? true : false )
        when 'fields'
          self.fields = v.split(',')
        when 'delimiter'
          self.delimiter =
            case v.to_s
            when 'tab'
              "\t"
            when 'null'
              "\x00"
            else
              v
            end
        end
      end
      self.open(file)

      if header and not fields.include?(FIELD_WILDCARD)
        self.fd.puts self.fields.join(self.delimiter)
        self.fd.flush
      end

    end

    def write_record(doc)
      out = []

      if self.fields.include?(FIELD_WILDCARD)
        doc.each_pair do |k,v|
          out << sanitize(v.to_s)
        end
      else
        self.fields.each do |k|
          out << sanitize(doc[k].to_s)
        end
      end

      return unless out.length > 0

      self.fd.puts out.join(self.delimiter)
      self.fd.flush
    end

  end

  #
  # JSON Output (line-delimited records)
  #
  class OutputJSON

    include FileDestination

    def initialize(args)
      self.open(args.first)
    end

    def write_record(doc)
      self.fd.puts Oj.dump(sanitize(doc))
      self.fd.flush
    end

  end


  #
  # CSV Output
  #
  class OutputCSV

    attr_accessor :fields, :delimiter
    FIELD_WILDCARD = '_'

    include FileDestination

    def initialize(args)
      file = nil
      self.delimiter = ","
      self.fields    = FIELD_WILDCARD

      header = false

      args.each do |str|
        k,v = str.split('=', 2)
        case k
        when 'file'
          file = v
        when 'header'
          header = ( v =~ /^[ty1]/i ? true : false )
        when 'fields'
          self.fields = v.split(',')
        when 'delimiter'
          self.delimiter =
            case v.to_s
            when 'tab'
              "\t"
            when 'null'
              "\x00"
            else
              v
            end
        end
      end
      self.open(file)

      if header and not fields.include?(FIELD_WILDCARD)
        self.fd.puts self.fields.to_csv
      end

    end

    def write_record(doc)
      out = []

      if self.fields.include?(FIELD_WILDCARD)
        doc.each_pair do |k,v|
          out << sanitize(v.to_s)
        end
      else
        self.fields.each do |k|
          out << sanitize(doc[k].to_s)
        end
      end

      return unless out.length > 0

      self.fd.puts out.to_csv
    end

  end

end
end
