module Dap
module Filter

require 'openssl'

class FilterDecodeX509
  include BaseDecoder

  def decode(data)
    save = {}
    cert = OpenSSL::X509::Certificate.new(data) rescue nil
    return unless cert 

    dnames = []
    cert.subject.to_s.split("/").each do |bit|
      var,val = bit.split("=", 2)
      next unless (var and val)
      var = var.to_s.downcase.strip
      save["s_#{var}"] = val 
      if var == "cn"
        dnames << val
      end
    end

    cert.issuer.to_s.split("/").each do |bit|
      var,val = bit.split("=", 2)
      next unless (var and val)
      var = var.to_s.downcase.strip
      save["i_#{var}"] = val 
    end

    cert.extensions.each do |e|
      next unless e.to_s =~ /^([^\s]+)\s*=\s*(.*)/
      var,val = $1,$2
      var = var.to_s.downcase.strip
      save["e_#{var}"] = val.strip

      if var == "subjectaltname"
        val.split(",").map{|x| x.gsub("DNS:", "").gsub("IP:", "").gsub("email:", "").strip }.each do |name|
          dnames << name
        end
      end

    end

    save["names"] = dnames
    save
  end

end

end
end