module Dap
module Input

  require 'csv'

  #
  # CSV
  #
  class InputCSV

    include FileSource

    attr_accessor :has_header, :headers

    def initialize(args)
      self.headers = []

      fname = args.shift
      self.open(fname)

      args.each do |arg|
        if arg =~ /^header=(.*)/
          val =$1
          self.has_header = !! (val =~ /^y|t|1/i)
        end
      end

      if self.has_header
        data = read_record
        unless (data == :eof or data == :empty)
          self.headers = data.values.map{|x| x.to_s.strip }
        end
      end
    end

    def read_record
      res = {}
      line = self.fd.readline rescue nil
      return Error::EOF unless line

      # Short-circuit the slow CSV parser if the data does not contain double quotes
      arr = line.index('"') ? 
        ( CSV.parse(line) rescue nil ) : 
        [ line.split(',').map{|x| x.strip } ]

      return Error::Empty unless arr
      cnt = 0
      arr.first.each do |x|
        cnt += 1
        if x.to_s.length > 0
          res[headers[cnt-1] || cnt.to_s] = x
        end
      end
      res
    end

  end

end
end
