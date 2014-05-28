#!/usr/bin/env ruby

require 'oj'

SEARCHES = {
  "data.ipmi_compat_password"           => { value: "1", name: "straight-pass" },
  "data.ipmi_compat_md2"                => { value: "1", name: "md2" },
  "data.ipmi_compat_none"               => { value: "1", name: "noauth" },
  "data.ipmi_user_disable_message_auth" => { value: "1", name: "permsg" },
  "data.ipmi_user_disable_user_auth"    => { value: "1", name: "usrlvl" }
}

def search(hash)
  SEARCHES.each do | key, vuln |
    if hash[key] == vuln[:value]
      hash["VULN-IPMI-#{vuln[:name].upcase}"] = "true"
    end
  end
  if (hash['data.ipmi_user_non_null'] == "0") && (hash['data.ipmi_user_null'] == "0")
    hash["VULN-IPMI-ANON"] = "true"
  end 
  hash
end

while line=gets
  puts Oj.dump(search(Oj.load(line.strip)))
end
