module Dap
module Filter

MATCH_FQDN = /^([a-z0-9\_\-]+\.)+[a-z0-9\-]+\.?$/
VALID_FQDNS_FILE = File.expand_path(File.join(File.dirname(__FILE__), "..", "..", "..", "data", "tlds-alpha-by-domain.txt"))


class FilterExtractHostname
  include BaseDecoder

  def initialize(*args)
    @valid_fqdns = IO.readlines(VALID_FQDNS_FILE).map(&:rstrip).map(&:downcase)
    super(*args)
  end

  def decode(data)
    data = data.strip.gsub(/.*\@/, '').gsub(/^\*+/, '').gsub(/^\.+/, '').gsub(/\.+$/, '').downcase
    return unless data =~ MATCH_FQDN

    return unless @valid_fqdns.include?(data.split('.').last)

    { 'hostname' => data }
  end
end

class FilterSplitDomains
  include Base
  def process(doc)
    lines = [ ]
    self.opts.each_pair do |k,v|
      if doc.has_key?(k)
        expand(doc[k]).each do |line|
          lines << doc.merge({ "#{k}.domain" => line })
        end
      end
    end
   lines.length == 0 ? [ doc ] : [ lines ]
  end

  def expand(data)
    names = []
    bits  = data.split('.')
    while (bits.length > 1)
      names << bits.join('.')
      bits.shift
    end
    names
  end
end


class FilterPrependSubdomains
  include Base
  def process(doc)
    lines = [ ]
    self.opts.each_pair do |k,v|
      if doc.has_key?(k)
        expand(doc[k], v).each do |line|
          lines << doc.merge({ k => line })
        end
      end
    end
   lines.length == 0 ? [ ] : [ lines ]
  end

  def expand(data, names)
    outp = [ data ]
    bits = data.split(".")
    subs = names.split(",")

    # Avoid www.www.domain.tld and mail.www.domain.tld
    return outp if subs.include?(bits.first)
    subs.each do |sub|
      outp << "#{sub}.#{data}"
    end

    outp
  end

end

#
# Acts like SplitDomains but strips out common dynamic IP RDNS formats
#
# XXX - Lots of work left to do
#

class FilterSplitNonDynamicDomains
  include Base
  def process(doc)
    lines = [ ]
    self.opts.each_pair do |k,v|
      if doc.has_key?(k)
        expand(doc[k]).each do |line|
          lines << doc.merge({ "#{k}.domain" => line })
        end
      end
    end
   lines.length == 0 ? [ doc ] : [ lines ]
  end

  def expand(data)
    names = []
    data  = data.unpack("C*").pack("C*").
      gsub(/.*ip\d+\.ip\d+\.ip\d+\.ip\d+\./, '').
      gsub(/.*\d+[\_\-\.x]\d+[\_\-\.x]\d+[\_\-\.x]\d+[^\.]+/, '').
      gsub(/.*node-[a-z0-9]+.*pool.*dynamic\./, '').
      gsub(/.*[a-z][a-z]\d+\.[a-z]as[a-z0-9]+\./, '').
      # cl223.001033200.technowave.ne.jp
      gsub(/^cl\d+.[0-9]{6,14}\./, '').
      # n157.s1117.m-zone.jp
      gsub(/^n\d+.s\d+\.m-zone.jp/, 'm-zone.jp').
      # u570054.xgsnu2.imtp.tachikawa.mopera.net
      # s505207.xgsspn.imtp.tachikawa.spmode.ne.jp
      gsub(/^[us]\d+.xgs[a-z0-9]+\.imtp/, 'imtp').
      # tzbm6501209.tobizaru.jp
      gsub(/^tzbm[0-9]{6,9}\./, '').
      # ARennes-556-1-256-bdcst.w2-14.abo.wanadoo.fr
      gsub(/.*\-\d+\-\d+\-\d+\-(net|bdcst)\./, '').
      # bl19-128-119.dsl.telepac.pt
      gsub(/.*\d+\-\d+\-\d+\.dsl/, 'dsl').
      gsub(/.*pool\./, '').
      gsub(/.*dynamic\./, '').
      gsub(/.*static\./, '').
      gsub(/.*dhcp[^\.]+\./, '').
      gsub(/^\d{6,100}\./, '').
      gsub(/^\.+/, '').
      tr('^a-z0-9.-', '')

    bits  = data.split('.')
    while (bits.length > 1)
      names << bits.join('.')
      bits.shift
    end
    names
  end
end


end
end
