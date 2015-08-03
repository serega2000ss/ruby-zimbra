module Zimbra
  class Domain < Zimbra::Base
    class << self
      def acl_name
        'domain'
      end
    end

    def count_accounts
      DomainService.count_accounts(id)
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

    class Builder
      class << self
        

        def count_accounts(message, id)
          message.add 'domain', id do |c|
            c.set_attr 'by', 'id'
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
