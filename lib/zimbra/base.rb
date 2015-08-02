module Zimbra

  # Doc Placeholder
  class Base
    NAMESPACES = {
      'Domain' => 'domain',
      'Account' => 'account',
      'DistributionList' => 'dl'
    }

    class << self
      def class_name
        name.gsub(/Zimbra::/, '')
      end

      def all
        Service.all(class_name)
      end

      def find_by_id(id)
        Service.get_by_id(id, class_name)
      end

      def find_by_name(name)
        Service.get_by_name(name, class_name)
      end
    end
  end

  # Doc Placeholder
  class Service < HandsoapService
    def all(class_name)
      request_name = "n2:GetAll#{class_name}sRequest"
      xml = invoke(request_name)
      Parser.get_all_response(class_name, xml)
    end

    def get_by_id(id, class_name)
      request_name = "n2:Get#{class_name}Request"
      xml = invoke(request_name) do |message|
        Builder.get_by_id(message, id, class_name)
      end
      return nil if soap_fault_not_found?
      namespace = Zimbra::Base::NAMESPACES[class_name]
      Parser.response(class_name, xml/"//n2:#{namespace}")
    end

    def get_by_name(name, class_name)
      request_name = "n2:Get#{class_name}Request"
      xml = invoke(request_name) do |message|
        Builder.get_by_name(message, name, class_name)
      end
      return nil if soap_fault_not_found?
      namespace = Zimbra::Base::NAMESPACES[class_name]
      Parser.response(class_name, xml/"//n2:#{namespace}")
    end
  end

  # Doc Placeholder
  class Builder
    class << self
      def get_by_id(message, id, class_name)
        namespace = Zimbra::Base::NAMESPACES[class_name]
        message.add namespace, id do |c|
          c.set_attr 'by', 'id'
        end
      end

      def get_by_name(message, name, class_name)
        namespace = Zimbra::Base::NAMESPACES[class_name]
        message.add namespace, name do |c|
          c.set_attr 'by', 'name'
        end
      end
    end
  end

  # Doc Placeholder
  class Parser
    class << self
      def get_all_response(class_name, response)
        namespace = Zimbra::Base::NAMESPACES[class_name]
        (response/"//n2:#{namespace}").map do |node|
          response(class_name, node, false)
        end
      end

      def response(class_name, node, full = true)
        parser_module = "Zimbra::#{class_name}Service::Parser"
        object = Object.const_get parser_module
        object.send("#{class_name.downcase}_response", node)
      end
    end
  end

end
