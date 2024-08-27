# JSON utilities

# This addon must be required before use

require 'json'

module ASFJSON
  # Compare JSON files
  # bc = breadcrumb
  # yield the changes for subsequent processing:
  # bc, type (Dropped, Scalar, Array, Added), key, args (scalar or array)
  def self.cmphash(h1, h2, bc=nil, &block)
    bc ||= ['root']
    h1.each do |k, v1|
      v2 = h2[k]
      if !h2.include? k
        yield [bc, 'Dropped', k, v1]
      elsif v1 != v2
        case v1.class.to_s
        when 'Array'
          yield [bc, 'Array', k, [v1, v2]]
        when 'Hash'
          self.cmphash v1, v2, [bc,k].flatten, &block
        else # treat as scalar
          yield [bc, 'Scalar', k, [v1, v2]]
        end
      end
    end
    # Now deal with items not in old (other items have been compared?)
    h2.each do |k,v2|
      v1 = h1[k]
      if v1.nil?
        yield [bc, 'Added', k, v2]
      end
    end
  end

  # Sample method to process differences
  def self.compare_json(old_json, new_json, out=$stdout)
    cmphash old_json, new_json do |bc, type, key, args|
      bcj = bc.join('.')
      case type
      when 'Scalar'
        v1, v2 = args
        out.puts [bcj, key, v1, '=>', v2].inspect
      when 'Array'
        v1, v2 = args
        dropped = v1 - v2
        added = v2 - v1
        if dropped.size == 0
          out.puts  [bcj, key, 'Added', v2-v1].inspect
        elsif added.size == 0
          out.puts  [bcj, key, 'Dropped', v1-v2].inspect
        else
          out.puts  [bcj, key, 'Dropped', v1-v2, 'Added', v2-v1].inspect
        end
      when 'Dropped'
        out.puts  [bcj, 'Dropped', key, args].inspect
      when 'Added'
        out.puts  [bcj, 'Added', key, args].inspect
      else
        raise ArgumentError.new "Unexpected type: #{type} in #{bc} #{key}"
      end
    end
  end

end

if __FILE__ == $0
  require 'stringio'
  old_file = ARGV.shift or raise ArgumentError.new 'Old file!'
  new_file = ARGV.shift or raise ArgumentError.new 'New file!'
  old_json = JSON.parse(File.read(old_file))
  new_json = JSON.parse(File.read(new_file))
  out = StringIO.new
  ASFJSON.compare_json(old_json, new_json, out=out)
  puts out.string

end
