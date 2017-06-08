module Zimbra
  class Account < Zimbra::Base
    class << self

      def create(name, password, attributes = {})
        AccountService.create(name, password, attributes)
      end

      def delete(zimbra_id)
        AccountService.delete(zimbra_id)
      end

      def mailbox(account_id)
        AccountService.mailbox(account_id)
      end

      def acl_name
        'usr'
      end
    end

    attr_accessor :cos_id


    # Returns an Array of Hashs
    # each hash has DL information
    def memberships
      AccountService.memberships(self)
    end

    def add_alias(alias_name)
      AccountService.add_alias(self, alias_name)
    end

    def archive_account
      # We ask the LDAP because SOAP doest not invalidate
      # the cache
      load_archive_info
      @archive_account
    end

    def archive_enabled
      load_archive_info
      @archive_enabled
    end

    def archive_enabled?
      archive_enabled == 'TRUE'
    end

    def enable_archive(cos_id = nil, archive_name = nil)
      return true if archive_enabled?
      archive_name ||= archive_account
      AccountService.enable_archive(self, cos_id, archive_name)
    end

    def disable_archive()
      return true unless archive_enabled?
      AccountService.disable_archive(self)
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

    def load_archive_info
      zimbra_attrs_to_load = Zimbra::Account.zimbra_attrs_to_load
      Zimbra::Account.zimbra_attrs_to_load = %w(zimbraArchiveEnabled zimbraArchiveAccount)
      account = Zimbra::Directory.search("zimbraId=#{id}")[:results].first
      @archive_enabled = account.zimbra_attrs['zimbraArchiveEnabled']
      @archive_account = account.zimbra_attrs['zimbraArchiveAccount']
      Zimbra::Account.zimbra_attrs_to_load = zimbra_attrs_to_load
    end

    def save
      AccountService.modify(id, self)
    end

    def update_zimbra_attrs(attrs_names)
      AccountService.update_zimbra_attrs(id, self, attrs_names)
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

    def delete(zimbra_id)
      xml = invoke('n2:DeleteAccountRequest') do |message|
        Builder.delete(message, zimbra_id)
      end
      xml.raw_xml.nil? ? true : false
    end

    def update_zimbra_attrs(id, account, attrs_names)
      xml = invoke("n2:ModifyAccountRequest") do |message|
        Builder.update_zimbra_attrs(message, id, account, attrs_names)
      end
      xml.raw_xml.nil? ? true : false
    end

    def enable_archive(account, cos_id, archive_name)
      # Only create the archive mbx if it does not exists
      create_archive = account.archive_account.nil? ? true : false
      xml = invoke('n2:EnableArchiveRequest') do |message|
        if create_archive
          Builder.create_archive(message, account, cos_id, archive_name)
        else
          Builder.enable_archive(message, account)
        end
      end
      xml.raw_xml.nil? ? true : false
    end

    def delegated_auth_token(id, duration)
      xml = invoke('n2:DelegateAuthRequest') do |message|
        Builder.delegated_auth_token(message, id, duration)
      end
      Parser.delegated_auth_token_response(xml)
    end

    def disable_archive(account)
      xml = invoke('n2:DisableArchiveRequest') do |message|
        Builder.disable_archive(message, account)
      end
      xml.raw_xml.nil? ? true : false
    end

    def mailbox(id)
      xml = invoke('n2:GetMailboxRequest') do |message|
        Builder.mailbox(message, id)
      end
      Parser.mailbox_response(xml)
    end

    def memberships(account)
      xml = invoke('n2:GetAccountMembershipRequest') do |message|
        Builder.memberships(message, account)
      end
      Parser.memberships_response(xml)
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

        def delete(message, zimbra_id)
          message.add 'id', zimbra_id
        end

        def create_archive(message, account, cos_id, archive_name)
          message.add 'account', account.id do |c|
            c.set_attr 'by', 'id'
          end
          message.add 'archive' do |c|
            c.set_attr 'create', 1
            c.add('name', archive_name) if archive_name
            c.add 'cos', cos_id do |c|
              c.set_attr 'by', 'id'
            end
          end
        end

        def delegated_auth_token(message, id, duration)
          message.set_attr 'duration', duration
          message.add 'account', id do |c|
            c.set_attr 'by', 'id'
          end
        end

        def enable_archive(message, account)
          message.add 'account', account.id do |c|
            c.set_attr 'by', 'id'
          end
          message.add 'archive' do |c|
            c.set_attr 'create', 0
            c.add 'name', account.archive_account
          end
        end

        def disable_archive(message, account)
          message.add 'account', account.id do |c|
            c.set_attr 'by', 'id'
          end
        end

        def memberships(message, account)
          message.add 'account', account.id do |c|
            c.set_attr 'by', 'id'
          end
        end

        def update_zimbra_attrs(message, id, account, attrs_names)
          message.set_attr 'id', id
          attrs_names.each do |attr_name|
            A.inject(message, attr_name, account.zimbra_attrs[attr_name]) if account.zimbra_attrs[attr_name]
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

        def memberships_response(response)
          return [] if (response/'//n2:dl').empty?
          (response/'//n2:dl').map do |dl|
            name = (dl/'@name').to_s
            id = (dl/'@id').to_s
            via = (dl/'@via').to_s
            OpenStruct.new(id: id, name: name, via: via)
          end
        end

      end
    end
  end
end
