#!/usr/bin/env ruby
info = {}
$stdin.each_line do |line|
  line = line.unpack("C*").pack("C*").strip
  info[line] ||= 0
  info[line]  +=1
end


puts "

#### Top Values
| Count        | Value |
|:------------- | ------------- |"

max = 100
cnt = 0
info.keys.sort {|a,b| info[b] <=> info[a] }.each do |k|
  puts "| #{info[k]} | #{k} |"
  cnt +=1
  break if cnt > max
end
puts ""
