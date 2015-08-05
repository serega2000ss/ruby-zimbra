module Zimbra
  class Account < Zimbra::Base
    class << self

      def create(name, password, attributes = {})
        AccountService.create(name, password, attributes)
      end

      def acl_name
        'usr'
      end
    end

    attr_accessor :cos_id

    def initialize(id, name, acls = [], zimbra_attrs = {}, node = nil)
      super
      self.cos_id = zimbra_attrs['zimbraCOSId']
      self.delegated_admin = zimbra_attrs['zimbraIsDelegatedAdminAccount']
    end

    def delegated_admin=(val)
      @delegated_admin = Zimbra::Boolean.read(val)
    end

    def delegated_admin?
      @delegated_admin
    end

    def save
      AccountService.modify(self)
    end

    def add_alias(alias_name)
      AccountService.add_alias(self,alias_name)
    end
  end

  # Doc Placeholder
  class AccountService < HandsoapService
    def create(name, password, attributes)
      xml = invoke("n2:CreateAccountRequest") do |message|
        Builder.create(message, name, password, attributes)
      end
      class_name = Zimbra::Account.class_name
      Zimbra::BaseService::Parser.response(class_name, xml/"//n2:account")
    end

    def add_alias(account,alias_name)
      xml = invoke('n2:AddAccountAliasRequest') do |message|
        Builder.add_alias(message,account.id,alias_name)
      end
    end

    # Doc Placeholder
    class Builder
      class << self
        def create(message, name, password, attributes)
          message.add 'name', name
          message.add 'password', password
          attributes.each do |k,v|
            A.inject(message, k, v)
          end
        end

        def modify(message, account)
          message.add 'id', account.id
          modify_attributes(message, distribution_list)
        end

        def modify_attributes(message, account)
          if account.acls.empty?
            ACL.delete_all(message)
          else
            account.acls.each do |acl|
              acl.apply(message)
            end
          end
          Zimbra::A.inject(node, 'zimbraCOSId', account.cos_id)
          Zimbra::A.inject(node, 'zimbraIsDelegatedAdminAccount', (delegated_admin ? 'TRUE' : 'FALSE'))
        end

        def delete(message, id)
          message.add 'id', id
        end

        def add_alias(message,id,alias_name)
          message.add 'id', id
          message.add 'alias', alias_name
        end
      end
    end
    class Parser
      class << self
      end
    end
  end
end
