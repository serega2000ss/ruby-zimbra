module Zimbra
  class Account < Zimbra::Base
    class << self

      def create(name, password, attributes = {})
        AccountService.create(name, password, attributes)
      end

      def mailbox(account_id)
        AccountService.mailbox(account_id)
      end

      def acl_name
        'usr'
      end
    end

    attr_accessor :cos_id

    def add_alias(alias_name)
      AccountService.add_alias(self, alias_name)
    end

    def initialize(id, name, zimbra_attrs = {}, node = nil)
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

    def delegated_auth_token(duration = 3600)
      AccountService.delegated_auth_token(id, duration)
    end

    def mailbox_size
      mailbox[:size]
    end

    def mailbox_store_id
      mailbox[:store_id]
    end

    def mailbox
      @mailbox ||= AccountService.mailbox(id)
    end

    def remove_alias(alias_name)
      AccountService.remove_alias(self, alias_name)
    end

    def save
      AccountService.modify(self)
    end

    def set_password(new_password)
      AccountService.set_password(id, new_password)
    end
  end

  # Doc Placeholder
  class AccountService < HandsoapService
    def create(name, password, attributes)
      xml = invoke('n2:CreateAccountRequest') do |message|
        Builder.create(message, name, password, attributes)
      end
      class_name = Zimbra::Account.class_name
      Zimbra::BaseService::Parser.response(class_name, xml/"//n2:account")
    end

    def delegated_auth_token(id, duration)
      xml = invoke('n2:DelegateAuthRequest') do |message|
        Builder.delegated_auth_token(message, id, duration)
      end
      Parser.delegated_auth_token_response(xml)
    end

    def mailbox(id)
      xml = invoke('n2:GetMailboxRequest') do |message|
        Builder.mailbox(message, id)
      end
      Parser.mailbox_response(xml)
    end

    def set_password(id, new_password)
      xml = invoke('n2:SetPasswordRequest') do |message|
        Builder.set_password(message, id, new_password)
      end
      xml.nil? ? nil : true
    end

    def add_alias(account, alias_name)
      xml = invoke('n2:AddAccountAliasRequest') do |message|
        Builder.add_alias(message, account.id, alias_name)
      end
      xml.nil? ? nil : true
    end

    def remove_alias(account, alias_name)
      xml = invoke('n2:RemoveAccountAliasRequest') do |message|
        Builder.remove_alias(message, account.id, alias_name)
      end
      xml.nil? ? nil : true
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

        def delegated_auth_token(message, id, duration)
          message.set_attr 'duration', duration
          message.add 'account', id do |c|
            c.set_attr 'by', 'id'
          end
        end

        def mailbox(message, id)
          message.add 'mbox' do |c|
            c.set_attr 'id', id
          end
        end

        def set_password(message, id, new_password)
          message.set_attr 'id', id
          message.set_attr 'newPassword', new_password
        end

        def add_alias(message, id, alias_name)
          message.set_attr 'id', id
          message.set_attr 'alias', alias_name
        end

        def remove_alias(message, id, alias_name)
          message.set_attr 'id', id
          message.set_attr 'alias', alias_name
        end
      end
    end
    class Parser
      class << self
        def mailbox_response(response)
          result = (response/'//n2:mbox')
          {
            size: (result/'@s').to_i,
            store_id: (result/'@mbxid').to_i
          }
        end

        def delegated_auth_token_response(response)
          (response/'//n2:DelegateAuthResponse/n2:authToken').to_s
        end

      end
    end
  end
end
