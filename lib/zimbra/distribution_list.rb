module Zimbra
  class DistributionList < Zimbra::Base
    class << self
      def acl_name
        'grp'
      end
    end

    attr_accessor :id, :name, :admin_console_ui_components, :admin_group
    attr_accessor :members, :restricted, :acls, :display_name, :cn, :mail

    def initialize(id, name, acls = [], zimbra_attrs = {}, node = nil)
      super
      @cn = zimbra_attrs['cn']
      @display_name = zimbra_attrs['displayName']
      self.admin_group = zimbra_attrs['zimbraIsAdminGroup']
      @members = Zimbra::DistributionListService::Parser.get_members node
      @restricted = !acls.nil?
      @original_members = self.members.dup
    end

    def admin_console_ui_components
      @admin_console_ui_components ||= []
    end

    def modify_members(new_members = [])
      return unless new_members.any?
      members = new_members
      DistributionListService.modify_members(self)
    end

    def members
      @members ||= []
    end

    def new_members
      self.members - @original_members
    end

    def removed_members
      @original_members - self.members
    end

    def admin_group=(val)
      @admin_group = Zimbra::Boolean.read(val)
    end
    def admin_group?
      @admin_group
    end

    def restricted?
      @restricted
    end

    def add_alias(alias_name)
      DistributionListService.add_alias(self,alias_name)
    end

    def save
      DistributionListService.modify(self)
    end
  end

  class DistributionListService < HandsoapService
    def create(name)
      xml = invoke("n2:CreateDistributionListRequest") do |message|
        Builder.create(message, name)
      end
      Parser.distribution_list_response(xml/'//n2:dl')
    end

    def modify_members(distribution_list)
      distribution_list.new_members.each do |member|
        add_member(distribution_list, member)
      end
      distribution_list.removed_members.each do |member|
        remove_member(distribution_list, member)
      end
      return true
    end

    def add_member(distribution_list, member)
      xml = invoke("n2:AddDistributionListMemberRequest") do |message|
        Builder.add_member(message, distribution_list.id, member)
      end
    end

    def remove_member(distribution_list, member)
      xml = invoke("n2:RemoveDistributionListMemberRequest") do |message|
        Builder.remove_member(message, distribution_list.id, member)
      end
    end

    def add_alias(distribution_list,alias_name)
      xml = invoke('n2:AddDistributionListAliasRequest') do |message|
        Builder.add_alias(message,distribution_list.id,alias_name)
      end
    end

    module Builder
      class << self
        def modify_admin_console_ui_components(message, distribution_list)
          if distribution_list.admin_console_ui_components.empty?
            A.inject(message, 'zimbraAdminConsoleUIComponents', '')
          else
            distribution_list.admin_console_ui_components.each do |component|
              A.inject(message, 'zimbraAdminConsoleUIComponents', component)
            end
          end
        end

        def modify_is_admin_group(message, distribution_list)
          A.inject(message, 'zimbraIsAdminGroup', (distribution_list.admin_group? ? 'TRUE' : 'FALSE'))
        end

        def add_member(message, distribution_list_id, member)
          message.add 'id', distribution_list_id
          message.add 'dlm', member
        end

        def remove_member(message, distribution_list_id, member)
          message.add 'id', distribution_list_id
          message.add 'dlm', member
        end

        def add_alias(message,id,alias_name)
          message.add 'id', id
          message.add 'alias', alias_name
        end
      end
    end

    # Doc Placeholder
    module Parser
      class << self
        def get_members(node)
          # Return this if we are getting here by find_by_*
          return (node/"//n2:dlm").map(&:to_s) if (node/"//n2:dlm").any?

          # Return this if we get here by DirectorySearch
          fwds = A.read(node, 'zimbraMailForwardingAddress')
          fwds.is_a?(Array) ? fwds.map(&:to_s) : [fwds]
        end
      end
    end
  end
end
