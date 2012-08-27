module DataMapper
  module Tags

    module SingletonMethods
      # Class Methods
      def tagged_with(string, options = {})
        tag = Tag.first(:name => string)
        conditions = {
          'taggings.tag_id'        => tag.kind_of?(Tag) ? tag.id : nil,
          'taggings.taggable_type' => self,
        }
        conditions['taggings.tag_context'] = options.delete(:on) if options.key?(:on)
        all(conditions.update(options))
      end

      def taggable?
        true
      end
    end

    module ClassMethods
      def has_tags_on(*associations)
        associations.flatten!
        associations.uniq!

        has n, :taggings, Tagging, :child_key => [ :taggable_id ], :taggable_type => self, :constraint => :destroy

        before :destroy, :destroy_taggings

        unless instance_methods(false).include?('destroy_taggings')
          class_eval <<-RUBY, __FILE__, __LINE__ + 1
            def destroy_taggings
              taggings.destroy!
            end
          RUBY
        end

        private :taggings, :taggings=, :destroy_taggings

        extend(DataMapper::Tags::SingletonMethods)

        associations.each do |association|
          association = association.to_s
          singular    = DataMapper::Inflector.singularize(association)
          class_eval <<-RUBY, __FILE__, __LINE__ + 1
            property :frozen_#{singular}_list, Text

            has n, :#{singular}_taggings, Tagging, :child_key => [ :taggable_id ], :taggable_type => self, :tag_context => '#{association}'
            has n, :#{association},       Tag,     :through => :#{singular}_taggings, :via => :tag, :order => [ :name ]

            def #{singular}_list
              @#{singular}_list ||= #{association}.map { |tag| tag.name }
            end

            def #{singular}_list=(string)
              @#{singular}_list = string.to_s.split(',').map { |name| name.gsub(/[^\\w\\s_-]/i, '').strip }.uniq.sort
              update_#{singular.pluralize}
            end

            alias_method :#{singular}_collection=, :#{singular}_list=

            def update_#{association}
              self.#{association} = #{singular}_list.map do |name|
                Tag.first_or_new(:name => name)
              end
              self.frozen_#{singular}_list = #{singular}_collection
            end

            ##
            # Helper methods to make setting tags easier
            #
            def #{singular}_collection
              #{association}.map { |tag| tag.name }.join(', ')
            end

            ##
            # Like tag_collection= except it only add's tags
            #
            def add_#{singular}(string)
              tag_names = string.to_s.split(',').map { |name| name.gsub(/[^\\w\\s_-]/i, '').strip }
              @#{singular}_list = tag_names.concat(#{singular}_list).uniq.sort
            end
          RUBY
        end
      end

      def has_tags(*)
        has_tags_on :tags
      end

      def taggable?
        false
      end
    end

    module InstanceMethods
      def taggable?
        model.taggable?
      end
    end

    def self.included(base)
      base.send(:include, InstanceMethods)
      base.extend(ClassMethods)
    end

  end # module Tags

  Model.append_inclusions DataMapper::Tags

end # module DataMapper
