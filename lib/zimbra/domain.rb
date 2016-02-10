module Zimbra
  class Domain < Zimbra::Base
    class << self
      def acl_name
        'domain'
      end

      def count_accounts(domain_id)
        DomainService.count_accounts(domain_id)
      end

    end

    def count_accounts
      DomainService.count_accounts(id)
    end

    # TODO: Maybe refactor to a better name
    # max_accounts is an integer
    # cos_max_accounts is an Arrays of 'COS_ids:total', like
    # 0ae7404d-4891-4ea4-a2d5-620a19b32b73:34 (34 is the total)
    def set_max_accounts(max_accounts = 0, cos_max_accounts = [])
      DomainService.set_max_accounts(id, max_accounts, cos_max_accounts)
    end

    def save
      DomainService.modify(self)
    end

  end

  class DomainService < HandsoapService

    def count_accounts(id)
      xml = invoke("n2:CountAccountRequest") do |message|
        Builder.count_accounts(message, id)
      end
      Parser.count_accounts_response(xml)
    end

    def delete
      xml = invoke("n2:DeleteDomainRequest") do |message|
        Builder.delete(message, id)
      end
    end

    def set_max_accounts(id, max_accounts, cos_max_accounts)
      xml = invoke('n2:ModifyDomainRequest') do |message|
        Builder.set_max_accounts(message, id, max_accounts, cos_max_accounts)
      end
      class_name = Zimbra::Domain.class_name
      Zimbra::BaseService::Parser.response(class_name, xml/'//n2:domain')
    end

    class Builder
      class << self
        def count_accounts(message, id)
          message.add 'domain', id do |c|
            c.set_attr 'by', 'id'
          end
        end

        def set_max_accounts(message, id, max_accounts, cos_max_accounts)
          message.add 'id', id
          A.inject(message, 'zimbraDomainMaxAccounts', max_accounts)
          # message.add 'a', max_accounts do |c|
          #   c.set_attr 'n', 'zimbraDomainMaxAccounts'
          # end
          cos_max_accounts.each do |cos|
            A.inject(message, 'zimbraDomainCOSMaxAccounts', cos)
            # message.add 'a', cos do |c|
            #   c.set_attr 'n', 'zimbraDomainCOSMaxAccounts'
            # end
          end
        end

        def delete(message, id)
          message.add 'id', id
        end
      end
    end
    class Parser
      class << self
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
