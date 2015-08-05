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
        BaseService.all(class_name)
      end

      def find_by_id(id)
        BaseService.get_by_id(id, class_name)
      end

      def find_by_name(name)
        BaseService.get_by_name(name, class_name)
      end

      def create(name, attrs = {})
        BaseService.create(name, attrs, class_name)
      end

    end

    attr_accessor :id, :name, :acls, :zimbra_attrs

    def initialize(id, name, acls = [], zimbra_attrs = {}, node = nil)
      self.id = id
      self.name = name
      self.acls = acls || []
      self.zimbra_attrs = zimbra_attrs
    end

    def delete
      BaseService.delete(id, self.class.class_name)
    end

    def modify(attrs = {})
      rename(attrs.delete('name')) if attrs['name']
      BaseService.modify(id, attrs, self.class.class_name)
    end

    # Zimbra only allows renaming domains directly through LDAP
    def rename(newname)
      fail Zimbra::HandsoapErrors::NotImplemented.new('Rename domain only via LDAP') if self.is_a?(Zimbra::Domain)
      BaseService.rename(id, newname, self.class.class_name)
    end

  end

  # Doc Placeholder
  class BaseService < HandsoapService
    def all(class_name)
      request_name = "n2:GetAll#{class_name}sRequest"
      xml = invoke(request_name)
      Parser.get_all_response(class_name, xml)
    end

    def delete(id, class_name)
      request_name = "n2:Delete#{class_name}Request"
      xml = invoke(request_name) do |message|
        Builder.delete(message, id)
      end
      true
    end

    def create(name, attributes = {}, class_name)
      request_name = "n2:Create#{class_name}Request"
      xml = invoke(request_name) do |message|
        Builder.create(message, name, attributes)
      end
      namespace = Zimbra::Base::NAMESPACES[class_name]
      Parser.response(class_name, xml/"//n2:#{namespace}")
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

    def modify(id, attributes = {}, class_name)
      request_name = "n2:Modify#{class_name}Request"
      xml = invoke(request_name) do |message|
        Builder.modify(message, id, attributes)
      end
      namespace = Zimbra::Base::NAMESPACES[class_name]
      Parser.response(class_name, xml/"//n2:#{namespace}")
    end

    def rename(id, newname, class_name)
      request_name = "n2:Rename#{class_name}Request"
      xml = invoke(request_name) do |message|
        Builder.rename(message, id, newname)
      end
      namespace = Zimbra::Base::NAMESPACES[class_name]
      Parser.response(class_name, xml/"//n2:#{namespace}")
    end

  # Doc Placeholder
    class Builder
      class << self

        def create(message, name, attributes = {})
          message.add 'name', name
          attributes.each do |k,v|
            A.inject(message, k, v)
          end
        end

        def delete(message, id)
          message.set_attr 'id', id
        end

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

        def modify(message, id, attributes)
          message.add 'id', id
          modify_attributes(message, attributes)
        end

        def modify_attributes(message, attributes = {})
          attributes.each do |k,v|
            A.inject(message, k, v)
          end
        end

        def rename(message, id, newname)
          message.set_attr 'id', id
          message.set_attr 'newName', newname
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
          attrs = full ? get_attributes(node) : {}
          id = (node/'@id').to_s
          name = (node/'@name').to_s
          acls = Zimbra::ACL.read(node)

          object = Object.const_get "Zimbra::#{class_name}"
          object.new(id, name, acls, attrs, node)
        end

        # This method run over the children of the node
        # and for each one gets the value of the n attribute
        # "<a n=\"zimbraMailAlias\">restringida@zbox.cl</a>"
        # would be zimbraMailAlias
        def get_attributes_names(node)
          (node/'n2:a').map { |e| (e/'@n').to_s }.uniq
        end

        def get_attributes(node)
          attr_hash = {}
          attributes = get_attributes_names node
          attributes.each do |attr|
            attr_hash[attr] = Zimbra::A.read node, attr
          end
          attr_hash
        end
      end
    end
  end

end
