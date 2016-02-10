module Zimbra

  # Doc Placeholder
  class Base
    NAMESPACES = {
      'Domain' => 'domain',
      'Account' => 'account',
      'DistributionList' => 'dl',
      'Cos' => 'cos'
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

      def zimbra_attrs_to_load=(array)
        fail(ArgumentError, 'Must be an array') unless array.is_a?Array
        @zimbra_attrs_to_load = array
      end

      def zimbra_attrs_to_load
        return [] if @zimbra_attrs_to_load.nil?
        @zimbra_attrs_to_load
      end

    end

    attr_accessor :id, :name, :zimbra_attrs

    def initialize(id, name, zimbra_attrs = {}, node = nil)
      self.id = id
      self.name = name
      self.zimbra_attrs = zimbra_attrs
    end

    def acls
      @acls ||= Zimbra::Directory.get_grants(self)
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

    def zimbra_type
      Zimbra::Directory::TARGET_TYPES_MAPPING[self.class]
    end

  end

  # Doc Placeholder
  class BaseService < HandsoapService
    def all(class_name)
      class_name_plural = class_name.downcase == 'cos' ? class_name : "#{class_name}s"
      request_name = "n2:GetAll#{class_name_plural}Request"
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
            # This is to be used if the value we are passing is an Array,
            # for example an account can have many 'mail' LDAP attributes,
            # or the Domain many zimbraDomainCOSMaxAccounts
            if v.is_a?Array
              v.each { |e| A.inject(message, k, e) }
            else
              A.inject(message, k, v)
            end
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
          object = Object.const_get "Zimbra::#{class_name}"
          names = full ? attributes_names(node) : object.zimbra_attrs_to_load
          attrs = get_attributes(node, names)

          id = (node/'@id').to_s
          name = (node/'@name').to_s
          object.new(id, name, attrs, node)
        end

        # This method run over the children of the node
        # and for each one gets the value of the n attribute
        # "<a n=\"zimbraMailAlias\">restringida@zbox.cl</a>"
        # would be zimbraMailAlias
        def attributes_names(node)
          (node/'n2:a').map { |e| (e/'@n').to_s }.uniq
        end

        def get_attributes(node, names = [])
          attr_hash = {}
          return attr_hash if names.empty?
          names.each do |attr|
            attr_hash[attr] = Zimbra::A.read node, attr
          end
          attr_hash
        end
      end
    end
  end

end
