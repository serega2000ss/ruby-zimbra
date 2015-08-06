module Zimbra
  class ACL
    class TargetObjectNotFound < StandardError; end

    TARGET_CLASSES = [Zimbra::Domain, Zimbra::DistributionList, Zimbra::Cos, Zimbra::Account]
    TARGET_MAPPINGS = TARGET_CLASSES.inject({}) do |hsh, klass|
      hsh[klass.acl_name] = klass
      hsh[klass] = klass.acl_name
      hsh
    end

    class << self
      def delete_all(xmldoc)
        A.inject(xmldoc, 'zimbraACE', '', 'c' => '1')
      end

      def read(node)
        list = A.read(node, 'zimbraACE')
        return nil if list.nil?
        list = [list] unless list.respond_to?(:map)
        acls = list.map do |ace|
          from_s(ace)
        end
      end

      def from_zimbra(node)
        from_s(node.to_s)
      end

      def from_s(value)
        grantee_id, grantee_name, name = value.split(' ')
        grantee_class = TARGET_MAPPINGS[grantee_name]
        return "Target object not found for acl #{value}" if target_class.nil?
        new(grantee_id: grantee_id, grantee_class: grantee_class, name: name)
      end
    end

    attr_accessor :grantee_id, :grantee_class, :name, :grantee_name

    def initialize(options = {})
      if options[:grantee]
        self.grantee_id = options[:grantee].id
        self.grantee_class = options[:grantee].class
        self.grantee_name = options[:grantee].grantee_name unless options[:grantee].grantee_name.nil?
      else
        self.grantee_id = options[:grantee_id]
        self.grantee_class = options[:grantee_class]
        self.grantee_name = options[:grantee_name] unless options[:grantee_name].nil?
      end
      self.name = options[:name]
    end

    def to_zimbra_acl_value
      id = grantee_id
      type = grantee_class.acl_name
      "#{id} #{type} #{name}"
    end

    def apply(xmldoc)
      A.inject(xmldoc, 'zimbraACE', to_zimbra_acl_value, 'c' => '1')
    end
  end
end
