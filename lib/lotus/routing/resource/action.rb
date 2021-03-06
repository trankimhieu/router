require 'lotus/utils/string'
require 'lotus/utils/path_prefix'
require 'lotus/utils/class_attribute'

module Lotus
  module Routing
    class Resource
      # Action for RESTful resource
      #
      # @since 0.1.0
      #
      # @api private
      #
      # @see Lotus::Router#resource
      class Action
        include Utils::ClassAttribute

        # Ruby namespace where lookup for default subclasses.
        #
        # @api private
        # @since 0.1.0
        class_attribute :namespace
        self.namespace = Resource

        # Accepted HTTP verb
        #
        # @api private
        # @since 0.1.0
        class_attribute :verb
        self.verb = :get

        # Separator for named routes
        #
        # @api private
        # @since 0.2.0
        class_attribute :named_route_separator
        self.named_route_separator = '_'.freeze

        # Generate an action for the given router
        #
        # @param router [Lotus::Router]
        # @param action [Lotus::Routing::Resource::Action]
        # @param options [Hash]
        #
        # @api private
        #
        # @since 0.1.0
        def self.generate(router, action, options)
          class_for(action).new(router, options)
        end

        # Initialize an action
        #
        # @param router [Lotus::Router]
        # @param options [Hash]
        # @param blk [Proc]
        #
        # @api private
        #
        # @since 0.1.0
        def initialize(router, options, &blk)
          @router, @options = router, options
          generate(&blk)
        end

        # Generate an action for the given router
        #
        # @param blk [Proc]
        #
        # @api private
        #
        # @since 0.1.0
        def generate(&blk)
          @router.send verb, path, to: endpoint, as: as
          instance_eval(&blk) if block_given?
        end

        # Resource name
        #
        # @api private
        # @since 0.1.0
        #
        # @example
        #   require 'lotus/router'
        #
        #   Lotus::Router.new do
        #     resource 'identity'
        #   end
        #
        #   # 'identity' is the name passed in the @options
        def resource_name
          @options[:name]
        end

        # Namespace
        #
        # @api private
        # @since 0.2.0
        def namespace
          @namespace ||= Utils::PathPrefix.new @options[:namespace]
        end

        private
        # Load a subclass, according to the given action name
        #
        # @param action [String] the action name
        #
        # @example
        #   Lotus::Routing::Resource::Action.send(:class_for, 'New') # =>
        #     Lotus::Routing::Resource::New
        #
        # @api private
        # @since 0.1.0
        def self.class_for(action)
          Utils::Class.load!(Utils::String.new(action).classify, namespace)
        end

        # Accepted HTTP verb
        #
        # @see Lotus::Routing::Resource::Action.verb
        #
        # @api private
        # @since 0.1.0
        def verb
          self.class.verb
        end

        # The namespaced URL relative path
        #
        # @example
        #   require 'lotus/router'
        #
        #   Lotus::Router.new do
        #     resources 'flowers'
        #
        #     namespace 'animals' do
        #       resources 'mammals'
        #     end
        #   end
        #
        #   # It will generate paths like '/flowers', '/flowers/:id' ..
        #   # It will generate paths like '/animals/mammals', '/animals/mammals/:id' ..
        #
        # @api private
        # @since 0.1.0
        def path
          rest_path
        end

        # The URL relative path
        #
        # @example
        #   '/flowers'
        #   '/flowers/new'
        #   '/flowers/:id'
        #
        # @api private
        # @since 0.1.0
        def rest_path
          namespace.join(resource_name)
        end

        # The namespaced name of the action within the whole context of the router.
        #
        # @example
        #   require 'lotus/router'
        #
        #   Lotus::Router.new do
        #     resources 'flowers'
        #
        #     namespace 'animals' do
        #       resources 'mammals'
        #     end
        #   end
        #
        #   # It will generate named routes like :flowers, :new_flowers ..
        #   # It will generate named routes like :animals_mammals, :animals_new_mammals ..
        #
        # @api private
        # @since 0.1.0
        def as
          namespace.relative_join(resource_name, self.class.named_route_separator).to_sym
        end

        # The name of the RESTful action.
        #
        # @example
        #   'index'
        #   'new'
        #   'create'
        #
        # @api private
        # @since 0.1.0
        def action_name
          Utils::String.new(self.class.name).demodulize.downcase
        end

        # A string that represents the endpoint to be loaded.
        # It is composed by controller and action name.
        #
        # @see Lotus::Routing::Resource::Action#separator
        #
        # @example
        #   'flowers#index'
        #
        # @api private
        # @since 0.1.0
        def endpoint
          [ resource_name, action_name ].join separator
        end

        # Separator between controller and action name
        #
        # @see Lotus::Routing::EndpointResolver#separator
        #
        # @example
        #   '#' # default
        #
        # @api private
        # @since 0.1.0
        def separator
          @options[:separator]
        end
      end

      # Collection action
      # It implements #collection within a #resource block.
      #
      # @api private
      # @since 0.1.0
      # @see Lotus::Router#resource
      class CollectionAction < Action
        def generate(&blk)
          instance_eval(&blk) if block_given?
        end

        protected
        def method_missing(m, *args)
          verb        = m
          action_name = Utils::PathPrefix.new(args.first).relative_join(nil)

          @router.__send__ verb, path(action_name),
            to: endpoint(action_name), as: as(action_name)
        end

        private
        def path(action_name)
          rest_path.join(action_name)
        end

        def endpoint(action_name)
          [ resource_name, action_name ].join separator
        end

        def as(action_name)
          [ action_name, super() ].join(self.class.named_route_separator).to_sym
        end
      end

      # Collection action
      # It implements #member within a #resource block.
      #
      # @api private
      # @since 0.1.0
      # @see Lotus::Router#resource
      class MemberAction < CollectionAction
      end

      # Implementation of common methods for concrete member actions
      #
      # @api private
      # @since 0.1.0
      module DefaultMemberAction
        private
        def path
          rest_path.join(action_name)
        end

        def as
          [ action_name, super ].join(self.class.named_route_separator).to_sym
        end
      end

      # New action
      #
      # @api private
      # @since 0.1.0
      # @see Lotus::Router#resource
      class New < Action
        include DefaultMemberAction
      end

      # Create action
      #
      # @api private
      # @since 0.1.0
      # @see Lotus::Router#resource
      class Create < Action
        self.verb = :post
      end

      # Show action
      #
      # @api private
      # @since 0.1.0
      # @see Lotus::Router#resource
      class Show < Action
      end

      # Edit action
      #
      # @api private
      # @since 0.1.0
      # @see Lotus::Router#resource
      class Edit < Action
        include DefaultMemberAction
      end

      # Update action
      #
      # @api private
      # @since 0.1.0
      # @see Lotus::Router#resource
      class Update < Action
        self.verb = :patch
      end

      # Destroy action
      #
      # @api private
      # @since 0.1.0
      # @see Lotus::Router#resource
      class Destroy < Action
        self.verb = :delete
      end
    end
  end
end
