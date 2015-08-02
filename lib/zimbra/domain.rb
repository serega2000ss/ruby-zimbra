module Zimbra
  class Domain < Zimbra::Base
    class << self
      def create(name, attributes = {})
        DomainService.create(name, attributes)
      end

      def acl_name
        'domain'
      end
    end

    attr_accessor :id, :name, :acls

    def initialize(id, name, acls = [])
      self.id = id
      self.name = name
      self.acls = acls || []
    end

    def get_attributes(attributes = [])
      return {} if attributes.empty?
      attr_hash = Hash.new
      raw = true
      raw_data = DomainService.get_by_id(id, raw)
      attributes.each do |attr|
        attr_hash[attr] = Zimbra::A.read raw_data, attr
      end
      attr_hash
    end

    def count_accounts
      DomainService.count_accounts(id)
    end

    def update_attributes(attributes = {})
      DomainService.modify(self, attributes)
    end

    def save
      DomainService.modify(self)
    end

    def delete
      DomainService.delete(self)
    end
  end

  class DomainService < HandsoapService

    def create(name, attributes = {})
      xml = invoke("n2:CreateDomainRequest") do |message|
        Builder.create(message, name, attributes)
      end
      Parser.domain_response(xml/"//n2:domain")
    end

    def count_accounts(id)
      xml = invoke("n2:CountAccountRequest") do |message|
        Builder.count_accounts(message, id)
      end
      Parser.count_accounts_response(xml)
    end

    def modify(domain, attributes = {})
      xml = invoke("n2:ModifyDomainRequest") do |message|
        Builder.modify(message, domain, attributes)
      end
      Parser.domain_response(xml/'//n2:domain')
    end

    def delete(dist)
      xml = invoke("n2:DeleteDomainRequest") do |message|
        Builder.delete(message, dist.id)
      end
    end

    class Builder
      class << self
        def create(message, name, attributes = {})
          message.add 'name', name
          attributes.each do |k,v|
            A.inject(message, k, v)
          end
        end

        def count_accounts(message, id)
          message.add 'domain', id do |c|
            c.set_attr 'by', 'id'
          end
        end

        def modify(message, domain, attributes = {})
          message.add 'id', domain.id
          modify_attributes(message, attributes)
        end

        def modify_attributes(message, attributes = {})
          attributes.each do |k,v|
            A.inject(message, k, v)
          end
        end

        def delete(message, id)
          message.add 'id', id
        end
      end
    end
    class Parser
      class << self

        def domain_response(node)
          id = (node/'@id').to_s
          name = (node/'@name').to_s
          acls = Zimbra::ACL.read(node)
          Zimbra::Domain.new(id, name, acls)
        end

        def count_accounts_response(response)
          hash = {}
          (response/"//n2:cos").map do |node|
            cos_id = (node/'@id').to_s
            hash[cos_id] = node.to_s.to_i
          end
          hash
        end

      end
    end
  end
end
