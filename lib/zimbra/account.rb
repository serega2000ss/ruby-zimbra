module Zimbra
  class Account < Zimbra::Base
    class << self

      def create(options)
        account = new(options)
        AccountService.create(account)
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

    def delete
      AccountService.delete(self)
    end

    def add_alias(alias_name)
      AccountService.add_alias(self,alias_name)
    end
  end

  # Doc Placeholder
  class AccountService < HandsoapService
    def create(account)
      xml = invoke("n2:CreateAccountRequest") do |message|
        Builder.create(message, account)
      end
      Parser.account_response(xml/"//n2:account")
    end

    def modify(account)
      xml = invoke("n2:ModifyAccountRequest") do |message|
        Builder.modify(message, account)
      end
      Parser.account_response(xml/'//n2:account')
    end

    def delete(dist)
      xml = invoke("n2:DeleteAccountRequest") do |message|
        Builder.delete(message, dist.id)
      end
    end

    def add_alias(account,alias_name)
      xml = invoke('n2:AddAccountAliasRequest') do |message|
        Builder.add_alias(message,account.id,alias_name)
      end
    end

    # Doc Placeholder
    class Builder
      class << self
        def create(message, account)
          message.add 'name', account.name
          message.add 'password', account.password
          A.inject(message, 'zimbraCOSId', account.cos_id)
          account.attributes.each do |k,v|
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
