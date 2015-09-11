module Zimbra
  class SearchFolder
    class << self
      def all()
        SearchFolderService.all()
      end

      def create(name, query)
        SearchFolderService.create(name, query)
      end

    end

    ATTRS = [
      :id, :uuid, :name, :query, :sort_by, :types, :view, :absolute_folder_path,
      :parent_folder_id, :parent_folder_uuid,
      :non_folder_item_count, :non_folder_item_size,
      :revision, :imap_next_uid, :imap_modified_sequence, :modified_sequence, :activesync_disabled,
      :modified_date
    ] unless const_defined?(:ATTRS)

    attr_accessor *ATTRS

    def initialize(args = {})
      self.attributes = args
    end

    def attributes=(args = {})
      ATTRS.each do |attr_name|
        self.send(:"#{attr_name}=", (args[attr_name] || args[attr_name.to_s])) if args.has_key?(attr_name) || args.has_key?(attr_name.to_s)
      end
    end
  end

  class SearchFolderService < HandsoapAccountService
    def all()
      xml = invoke("n2:GetSearchFolderRequest")
      parse_xml_responses(xml)
    end

    def parse_xml_responses(xml)
      Parser.get_all_response(xml)
    end

    def create(name, query)
      # TROUBLESHOOTING HELP
      # document = Handsoap::XmlMason::Document.new do |doc|
      #   doc.add "CreateSearchFolderRequest" do |message|
      #     Builder.create(message, name, query)
      #   end
      # end

      response = invoke("n2:CreateSearchFolderRequest") do |message|
        Builder.create(message, name, query)
      end
      parse_xml_responses(response)
    end

    class Builder
      class << self
        def create(message, name, query)
          message.add 'search' do |s|
            s.set_attr 'name', name
            s.set_attr 'query', query
            s.set_attr 'types', 'conversation'
            s.set_attr 'l', '1'
          end
        end
      end
    end

    class Parser
      class << self
        ATTRIBUTE_MAPPING = {
          :query => :query,
          :sortBy => :sort_by,
          :types => :types,
          :id => :id,
          :uuid => :uuid,
          :name => :name,
          :view => :view,
          :absFolderPath => :absolute_folder_path,
          :l => :parent_folder_id,
          :luuid => :parent_folder_uuid,
          :n => :non_folder_item_count,
          :s => :non_folder_item_size,
          :rev => :revision,
          :i4next => :imap_next_uid,
          :i4ms => :imap_modified_sequence,
          :ms => :modified_sequence,
          :activesyncdisabled => :activesync_disabled,
          :md => :modified_date
        }

        def get_all_response(response)
          (response/"//n2:search").map do |node|
            searchfolder_response(node)
          end
        end

        def searchfolder_c_response(node)
          id = (node/'@id').to_s
          name = (node/'@name').to_s
          query = (node/'@query').to_s
          Zimbra::SearchFolder.new(id, name, query)
        end

        def searchfolder_response(node)
          searchfolder_attributes = ATTRIBUTE_MAPPING.inject({}) do |attrs, (xml_name, attr_name)|
            attrs[attr_name] = (node/"@#{xml_name}").to_s
            attrs
          end
          initialize_from_attributes(searchfolder_attributes)
        end

        def initialize_from_attributes(searchfolder_attributes)
          Zimbra::SearchFolder.new(searchfolder_attributes)
        end
      end
    end
  end
end
