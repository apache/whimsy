# Hack to ensure multiple lines are in the same 'pre' block
module Wunderbar
  class XmlMarkup
    def system(*args)
      opts = {}
      opts = args.pop if Hash === args.last

      tag = opts[:tag] || 'pre'
      merge_lines = tag == 'pre' # merge lines of the same type
      output_class = opts[:class] || {}
      output_class[:stdin]  ||= '_stdin'
      output_class[:stdout] ||= '_stdout'
      output_class[:stderr] ||= '_stderr'
      output_class[:hilite] ||= '_stdout _hilite'

      out = []
      okind = nil
      rc = super(*args, opts) do |kind, line|
        if merge_lines
          if okind && kind != okind && !out.empty? # change of kind
            tag! tag, out.join("\n"), class: output_class[okind]
            out = []
          end
          out << line
        else # normal; no accumulation of lines
          tag! tag, line, class: output_class[kind]
        end
        okind = kind
      end
      # Output last line(s)
      unless out.empty?
        tag! tag, out.join("\n"), class: output_class[okind]
      end
      return rc
    end
  end
end
