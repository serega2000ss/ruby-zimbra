require 'pp'

module Zimbra
  # Doc
  class AuthAccount
    def self.login(username, password)
      AuthAccountService.login(username, password)
    end
  end

  # Doc
  class AuthAccountService < Handsoap::Service
    include Zimbra::HandsoapErrors
    include Zimbra::HandsoapAccountNamespaces
    extend Zimbra::HandsoapAccountUriOverrides

    def on_create_document(doc)
      doc.alias 'n1', 'urn:zimbra'
      doc.alias 'n2', 'urn:zimbraAccount'
      doc.alias 'env', 'http://schemas.xmlsoap.org/soap/envelope/'
    end

    def on_response_document(doc)
      doc.add_namespace 'n2', 'urn:zimbraAccount'
    end

    def login(username, password)
      xml = invoke('n2:AuthRequest') do |message|
        Builder.auth(message, username, password)
      end
      [Parser.auth_token(xml), Parser.session_lifetime(xml)]
    end

    # Doc
    class Builder
      class << self
        def auth(message, username, password)
          message.add 'password', password
          message.add 'account', username do |c|
            c.set_attr 'by', 'name'
          end
        end
      end
    end

    # Doc
    class Parser
      class << self
        def auth_token(response)
          (response / '//n2:authToken').to_s
        end

        def session_lifetime(response)
          (response / '//n2:lifetime').to_s
        end
      end
    end
  end
end
