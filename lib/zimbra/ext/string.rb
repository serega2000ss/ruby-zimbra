module Zimbra
  class String < ::String

    class << self
      def camel_case_lower(string)
        string.split('_').inject([]){ |buffer,e| buffer.push(buffer.empty? ? e : e.capitalize) }.join
      end
    end
  end
end
