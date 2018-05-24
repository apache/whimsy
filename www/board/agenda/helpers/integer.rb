# Add the right prefix to a number
unless Integer.public_method_defined? :ordinalize
  class Integer
    def ordinalize
      if self % 10 == 1
        self.to_s + "st"
      elsif self % 10 == 2
        self.to_s + "nd"
      else
        self.to_s + "th"
      end
    end
  end
end
