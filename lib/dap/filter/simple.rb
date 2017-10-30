require 'digest/sha1'
require 'digest/md5'
require 'digest/sha2'
require 'json'

module Dap
module Filter

class FilterCopy
  include Base

  def process(doc)
    self.opts.each_pair do |k,v|
      if doc.has_key?(k)
        doc[v] = doc[k]
      end
    end
   [ doc ]
  end
end

class FilterRename
  include Base

  def initialize(args)
    super
    missing_rename = self.opts.select { |k, v| v.nil? }.keys
    unless missing_rename.empty?
      fail "Missing new name for renames of #{missing_rename.join(',')}"
    end
  end

  def process(doc)
    self.opts.each_pair do |k,v|
      if doc.has_key?(k)
        doc[v] = doc[k]
        doc.delete(k)
      end
    end
   [ doc ]
  end
end

# Example below replaces periods with underscores in the names of all keys
# one level below 'my_key'
# rename_subkey_match my_key '.' '_'
class FilterRenameSubkeyMatch
  include Base

  def initialize(args)
    super
    fail "Expected 3 arguments to '#{self.name}' but got #{args.size}" unless args.size == 3
    self.opts = args
  end

  def process(doc)
    temp_field = {}
    field, original, updated = self.opts
    return [ doc ] unless doc[field].is_a?(::Hash)
    doc[field].each_key do |k|
      new_k = k.gsub(original, updated)
      temp_field[new_k] = doc[field][k]
    end
    doc[field] = temp_field
    [ doc ]
  end
end

class FilterMatchRemove
  include Base
  def process(doc)
    self.opts.each_pair do |re,_|
      doc.each_key do |k|
        if k.match(re)
          doc.delete(k)
        end
      end
    end
   [ doc ]
  end
end

class FilterRemove
  include Base
  def process(doc)
    self.opts.each_pair do |k,v|
      if doc.has_key?(k)
        doc.delete(k)
      end
    end
   [ doc ]
  end
end

class FilterMatchSelect
  include Base
  def process(doc)
    ndoc = {}
    self.opts.each_pair do |re,|
      doc.each_key do |k|
        if k.match(re)
          ndoc[k] = doc[k]
        end
      end
    end
   (ndoc.keys.length == 0) ? [] : [ ndoc ]
  end
end

class FilterSelect
  include Base
  def process(doc)
    ndoc = {}
    self.opts.each_pair do |k,v|
      if doc.has_key?(k)
        ndoc[k] = doc[k]
      end
    end
   (ndoc.keys.length == 0) ? [] : [ ndoc ]
  end
end

class FilterInsert
  include Base
  def process(doc)
    self.opts.each_pair do |k,v|
        doc[k] = v
    end
   [ doc ]
  end
end

class FilterInclude
  include Base
  def process(doc)
    self.opts.each_pair do |k,v|
      if doc.has_key?(k) and doc[k].to_s.index(v)
        return [ doc ]
      end
    end
    [ ]
  end
end

# where 'some.field == some_value'
# where 'some.field != some_value'
# TODO: do something other than basic string comparison.  Would be nice to have where 'some.field > 2', etc
class FilterWhere
  attr_accessor :query

  def initialize(args)
    fail "Expected 3 arguments to 'where' but got #{args.size}" unless args.size == 3
    self.query = args
  end

  def process(doc)
    field, operator, expected = self.query
    return [ doc ] if doc.has_key?(field) and doc[field].send(operator, expected)
    [ ]
  end
end

class FilterExclude
  include Base
  def process(doc)
    self.opts.each_pair do |k,v|
      if doc.has_key?(k) and doc[k].to_s.index(v)
        return [ ]
      end
    end
    [ doc ]
  end
end

class FilterExists
  include Base
  def process(doc)
    self.opts.each_pair do |k,v|
      if doc.has_key?(k) and doc[k].to_s.length > 0
        return [ doc ]
      end
    end
    [ ]
  end
end

class FilterNotExists < FilterExists
  include Base
  def process(doc)
    exists_doc = super(doc)
    exists_doc.empty? ? [ doc ] : [ ]
  end
end

# Applies some simple annotation to the given fields, adding another
# field name with the appended annotation type, i.e.:
#
# $  echo '{"foo":"blah"}' | dap json stdin + annotate foo=length +  json
# {"foo":"bar","foo.length":4}
class FilterAnnotate
  include Base
  def process(doc)
    self.opts.each_pair do |k,v|
      if doc.has_key?(k)
        case v
        when 'length'
          doc["#{k}.length"] = doc[k].length
        when 'size'
          doc["#{k}.size"] = doc[k].size
        else
          fail "Unsupported annotation '#{v}'"
        end
      end
    end
    [ doc ]
  end
end

class FilterTransform
  include Base
  def process(doc)
    self.opts.each_pair do |k,v|
      if doc.has_key?(k)
        case v
        when /^int(?<base>\d+)?$/
          base = $LAST_MATCH_INFO['base']
          if base.nil?
            doc[k] = doc[k].to_s.to_i
          else
            doc[k] = doc[k].to_s.to_i(base.to_i)
          end
        when 'float'
          doc[k] = doc[k].to_f
        when 'reverse'
          doc[k] = doc[k].to_s.reverse
        when 'downcase'
          doc[k] = doc[k].to_s.downcase
        when 'upcase'
          doc[k] = doc[k].to_s.upcase
        when 'ascii'
          doc[k] = doc[k].to_s.gsub(/[\x00-\x1f\x7f-\xff]/n, '')
        when 'json'
          doc[k] = JSON.parse(doc[k].to_s)
        when 'utf8encode'
          doc[k] = doc[k].to_s.encode!('UTF-8', invalid: :replace, undef: :replace, replace: '')
        when 'base64decode'
          doc[k] = doc[k].to_s.unpack('m*').first
        when 'base64encode'
          doc[k] = [doc[k].to_s].pack('m*').gsub(/\s+/n, '')
        when 'qprintdecode'
          doc[k] = doc[k].to_s.gsub(/=([0-9A-Fa-f]{2})/n){ |x| [x[1,2]].pack("H*") }
        when 'qprintencode'
          doc[k] = doc[k].to_s.gsub(/[\x00-\x20\x3d\x7f-\xff]/n){|x| ( "=%.2x" % x.unpack("C").first ).upcase }
        when 'hexdecode'
          doc[k] = [ doc[k].to_s ].pack("H*")
        when 'hexencode'
          doc[k] = doc[k].to_s.unpack("H*").first
        else
          fail "Invalid transform '#{v}'"
        end
      end
    end
   [ doc ]
  end
end

class FilterFlatten
  include Base
  def process(doc)
    self.opts.each_pair do |k,|
      if doc.has_key?(k) and doc[k].is_a?(Hash)
        doc[k].each_pair do |fk,fv|
          doc["#{k}.#{fk}"] = fv
        end
      end
    end
   [ doc ]
  end
end

class FilterExpand
  include Base
  def process(doc)
    new_doc = doc.clone
    self.opts.each_pair do |k,|
      k_re = /^#{k}\.(?<sub_key>.+)$/
      doc.each do |fk,fv|
        if md = k_re.match(fk)
          new_doc[k] ||= {}
          new_doc[k][md[:sub_key]] = fv
        end
      end
    end
   [ new_doc ]
  end
end

class FilterTruncate
  include Base
  def process(doc)
    self.opts.each_pair do |k,v|
      if doc.has_key?(k)
        doc[k] = doc[k].to_s[0, v.to_i]
      end
    end
   [ doc ]
  end
end

class FilterSplitLine
  include Base
  def process(doc)
    lines = [ ]
    self.opts.each_pair do |k,v|
      if doc.has_key?(k)
        doc[k].to_s.split(/\n/).each do |line|
          lines << doc.merge({ "#{k}.line" => line })
        end
      end
    end
   lines.length == 0 ? [ doc ] : [ lines ]
  end
end

class FilterSplitWord
  include Base
  def process(doc)
    lines = [ ]
    self.opts.each_pair do |k,v|
      if doc.has_key?(k)
        doc[k].to_s.split(/\W/).each do |line|
          lines << doc.merge({ "#{k}.word" => line })
        end
      end
    end
   lines.length == 0 ? [ doc ] : [ lines ]
  end
end

class FilterSplitTab
  include Base
  def process(doc)
    lines = [ ]
    self.opts.each_pair do |k,v|
      if doc.has_key?(k)
        doc[k].to_s.split(/\t/).each do |line|
          lines << doc.merge({ "#{k}.tab" => line })
        end
      end
    end
   lines.length == 0 ? [ doc ] : [ lines ]
  end
end


class FilterSplitComma
  include Base
  def process(doc)
    lines = [ ]
    self.opts.each_pair do |k,v|
      if doc.has_key?(k)
        doc[k].to_s.split(/,/).each do |line|
          lines << doc.merge({ "#{k}.word" => line })
        end
      end
    end
   lines.length == 0 ? [ doc ] : [ lines ]
  end
end

class FilterSplitArray
  include Base
  def process(doc)
    lines = [ ]
    self.opts.each_pair do |k,v|
      if doc.has_key?(k) and doc[k].respond_to?(:each)
        doc[k].each do |line|
          lines << doc.merge({ "#{k}.item" => line })
        end
      end
    end
   lines.length == 0 ? [ doc ] : [ lines ]
  end
end

class FilterFieldSplit
  include Base
  def process(doc)
    self.opts.each_pair do |k,v|
      if doc.has_key?(k)
        count = 1
        doc[k].to_s.split(Regexp.new(v)).each do |thing|
          doc.merge!({ "#{k}.f#{count}" => thing })
          count += 1
        end
      end
    end
   [ doc ]
  end
end

class FilterFieldSplitLine < FilterFieldSplit
  def initialize(args)
    super(args.map { |arg| "#{arg}=\\n" } )
  end
end

class FilterFieldSplitWord < FilterFieldSplit
  def initialize(args)
    super(args.map { |arg| "#{arg}=\\W" } )
  end
end

class FilterFieldSplitTab < FilterFieldSplit
  def initialize(args)
    super(args.map { |arg| "#{arg}=\\t" } )
  end
end

class FilterFieldSplitComma < FilterFieldSplit
  def initialize(args)
    super(args.map { |arg| "#{arg}=," } )
  end
end

class FilterFieldSplitPeriod < FilterFieldSplit
  def initialize(args)
    super(args.map { |arg| "#{arg}=\\." } )
  end
end

class FilterFieldSplitArray
  include Base
  def process(doc)
    self.opts.each_pair do |k,v|
      if doc.has_key?(k) and doc[k].respond_to?(:each)
        wcount = 1
        doc[k].each do |word|
          doc.merge!({ "#{k}.f#{wcount}" => word })
          wcount += 1
        end
      end
    end
   [ doc ]
  end
end

class FilterFieldArrayJoinComma
  include Base
  def process(doc)
    self.opts.each_pair do |k,v|
      if doc.has_key?(v) and doc[v].respond_to?(:each)
        doc[k] = doc[v].join(",")
      end
    end
   [ doc ]
  end
end

class FilterFieldArrayJoinWhitespace
  include Base
  def process(doc)
    self.opts.each_pair do |k,v|
      if doc.has_key?(v) and doc[v].respond_to?(:each)
        doc[k] = doc[v].join(" ")
      end
    end
   [ doc ]
  end
end

class FilterDigest
  include Base
  def process(doc)
    self.opts.each_pair do |k,v|
      if doc.has_key?(k)
        case v
        when 'sha1'
          doc["#{k}.sha1"] = Digest::SHA1.hexdigest(doc[k].to_s)
        when 'md5'
          doc["#{k}.md5"] = Digest::MD5.hexdigest(doc[k].to_s)
        when 'sha256'
          doc["#{k}.sha256"] = Digest::SHA256.hexdigest(doc[k].to_s)
        end
      end
    end
   [ doc ]
  end
end

end
end
