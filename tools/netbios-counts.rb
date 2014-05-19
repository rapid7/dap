require 'oj'
require 'optparse'

options = Hash.new(0)
OptionParser.new do |opts|
  opts.banner = "Usage: netbios-counts.rb [options]"

  opts.on("-c", "--count [NUM]", OptionParser::DecimalInteger, 
          "Specify the number of top results") do |count|
    options[:top_count] = count
  end
end.parse!

NUM_TOP_RECORDS = options[:top_count] > 1 ? options[:top_count] : 5

module NameCounter
  def count(hash)
    name = hash[field].to_s
    @names[name] += 1 unless (name.empty? || name == 'UNKNOWN')
  end

  def top_names
    [].tap do |counts|
      ordered_names.to_a.take(NUM_TOP_RECORDS).each do |values|
        counts << { name: values[0], count: values[1] }
      end
    end
  end

  def ordered_names
    Hash[@names.sort_by{|k, v| v}.reverse] 
  end
end

class CompanyNameCounter
  include NameCounter

  def initialize
    @names = Hash.new(0)
  end

  def field
    'data.netbios_mac_company'
  end
end

class NetbiosNameCounter
  include NameCounter

  def initialize
    @names = Hash.new(0)
  end

  def field
    'data.netbios_hname'
  end
end

company_counter = CompanyNameCounter.new
netbios_counter = NetbiosNameCounter.new

while line=gets
  hash = Oj.load(line.strip)
  company_counter.count(hash)
  netbios_counter.count(hash)
end

summary = {
  'top_companies'     => company_counter.top_names,
  'top_netbios_names' => netbios_counter.top_names
}

puts Oj.dump(summary)
