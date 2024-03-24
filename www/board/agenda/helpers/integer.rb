# Add the right prefix to a number
unless Integer.public_method_defined? :ordinalize
  class Integer
    def ordinalize
      case self % 100
      when 11, 12, 13 then self.to_s + 'th'
      else
        case self % 10
        when 1 then self.to_s + 'st'
        when 2 then self.to_s + 'nd'
        when 3 then self.to_s + 'rd'
        else self.to_s + 'th'
        end
      end
    end
  end
end
