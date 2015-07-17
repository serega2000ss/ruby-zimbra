module Zimbra
  module Directory
    class << self
      # Run a search over the Ldap server of Zimbra
      # query: is a valid LDAP search query
      # types: a comma separated string of types of objects to look for
      # domain: the email domain you want to limit the search to
      # options[:limit]: max results of the search
      # options[:offset]
      # options[:sort_by]
      # options[:sort_ascending]: 1=true , 0=false
      def search(query = '', type: 'account', domain: nil, **options)
        options[:limit] ||= 25
        DirectoryService.search(query, type.to_sym, domain, options)
      end
    end
  end

  class DirectoryService < HandsoapService
    # This are the type off types (objects) that Zimbra has
    # "distributionlists,aliases,accounts,dynamicgroups,resources,domains"
    ZIMBRA_TYPES_HASH = {
      distribution_list: { zimbra_type: 'distributionlists', node_name: 'dl', class: Zimbra::DistributionList },
      #alias: { zimbra_type: 'aliases', node_name: 'alias', class: Zimbra::Alias },
      account: { zimbra_type: 'accounts', node_name: 'account', class: Zimbra::Account },
      domain: { zimbra_type: 'domains', node_name: 'domain', class: Zimbra::Domain }
    }

    def search(query, type, domain, options = {})
      xml = invoke("n2:SearchDirectoryRequest") do |message|
        Builder.search_directory(message, query, type, domain, options)
      end
      return nil if soap_fault_not_found?
      Parser.search_directory_response(xml, type)
    end

    # method to get the grants on an object
    # check https://files.zimbra.com/docs/soap_api/8.5.0/api-reference/zimbraAdmin/GetGrants.html
    def get_grants(id, type)
      xml = invoke('n2:GetGrantsRequest') do |message|
        Builder.get_grants(message, id, type)
      end
      return nil if soap_fault_not_found?
      Parser.get_grants_response(xml, type)
    end

    module Builder
      class << self
        def search_directory(message, query, type, domain, options)
          message.set_attr 'types', ZIMBRA_TYPES_HASH[type][:zimbra_type]
          message.set_attr 'query', query
          message.set_attr('domain', domain) if domain
          message.set_attr('limit', options[:limit]) if options[:limit]
          message.set_attr('offset', options[:offset]) if options[:offset]
          message.set_attr('sort_by', options[:sort_by]) if options[:sort_by]
          message.set_attr('sort_ascending', options[:sort_ascending]) if options[:sort_ascending]
        end

        def get_grants(message, id, type)
          message.add 'target', id do |c|
            c.set_attr 'by', 'id'
            c.set_attr 'type', type
          end
        end
      end
    end

    module Parser
      class << self
        def search_directory_response(response, type)
          # look for the node given by the type
          items = (response/"//n2:#{ZIMBRA_TYPES_HASH[type][:node_name]}")
          items.map { |i| object_list_response(i, type) }
        end

        def get_grants_response(response, type)
          opts = []
          grants = (response/"//n2:grant")
          grants.each do |n|
            hash = {}
            hash[:target_id] = (n/'n2:grantee'/'@id').to_s
            hash[:target_class] = Zimbra::ACL::TARGET_MAPPINGS[(n/'n2:grantee'/'@type').to_s]
            hash[:target_name] = (n/'n2:grantee'/'@name').to_s
            hash[:name] = (n/'n2:right').to_s
            opts << Zimbra::ACL.new(hash)
          end
          opts
        end

        # This just call the parser_response method of the object
        # in the case of the account type, it will call
        # Zimbra::AccountService::Parser.account_response(node)
        def object_list_response(node, type)
          node = clean_node node
          parser_module = ZIMBRA_TYPES_HASH[type][:class].name + 'Service::Parser'
          object = Object.const_get parser_module
          object.send("#{type.to_s}_response", node)
        end

        # This method is to erase all others nodes from document
        # so the xpath search like (//xxxx) works, beacuse (//) always start
        # at the beginning of the document, not the current element
        def clean_node(node)
          element = node.instance_variable_get("@element")
          directory_response = element.document.css("n2|SearchDirectoryResponse", 'n2' => 'urn:zimbraAdmin').first
          directory_response.children.each {|c| c.remove}
          directory_response.add_child element
          node
        end

      end
    end
  end
end
