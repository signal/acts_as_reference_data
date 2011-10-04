require 'acts_as_reference_data/railtie' if defined?(Rails)

# An ActiveRecord extension that allows a model to be marked as reference data.
# Models marked as such will have a number of methods automatically created.
# These methods will only query the database a single time to lookup the data.
module ActsAsReferenceData
  def self.included(klass)
    klass.extend(ActiveRecordExtension)
  end

  module ActiveRecordExtension
    def acts_as_reference_data(options = {})
      if options[:synonyms]
        options[:synonyms].each do |real, synonym|
          real, synonym = [real, synonym].map(&:to_s)

          class_eval <<-END, __FILE__, __LINE__ + 1
            def self.#{synonym.upcase}
              self.#{real.upcase}
            end

            def self.#{synonym.upcase}!
              self.#{real.upcase}!
            end

            def #{synonym.downcase}?
              #{real.downcase}?
            end
          END
        end
      end

      class_eval <<-END, __FILE__, __LINE__ + 1
        before_destroy :fail_on_destroy
        before_create :fail_on_create
        before_save :fail_on_modifying_code

        include ActsAsReferenceData::InstanceMethods
        extend ActsAsReferenceData::ClassMethods

        class << self
          def all_by_code
            @__reference_data__ ||= load_reference_data
          end
        end
      END

      install_dynamic_loading_hook
      __reference_data_classes__ << self
    end

    def __reference_data_classes__
      @@__reference_data_classes__ ||= Set.new
    end

    # Clears out all in memory cached objects for all reference data classes.
    def reset_reference_data
      self.__reference_data_classes__.each do |klass|
        klass.reset
      end
    end
  end

  module ClassMethods
    def [](code)
      self.all_by_code[code.to_s.upcase]
    end

    def reset
      @__reference_data__ = nil
    end

    def loaded?
      defined?(@__reference_data__) && !@__reference_data__.empty?
    end

    def loading?
      defined?(@__loading_ref_data) && @__loading_ref_data
    end

    private
    def load_reference_data
      # Stop any infinite recursion attempts
      return if loading?

      @__loading_ref_data = true

      reference_data = {}
      self.find(:all).each do |data|
        reference_data[data.attributes['code'].upcase] = data.freeze
      end

      logger.debug { "Loaded #{reference_data.keys.inspect} for #{self}" }

      reference_data.each do |code,obj|
        class_eval <<-END, __FILE__, __LINE__ + 1
          def self.#{code}
            self['#{code}']
          end

          def self.#{code}!
            self.find(#{obj.id})
          end

          def #{code.downcase}?
            code.upcase == '#{code}'
          end

          def full_instance
            self.class.find(self.id)
          end
        END

        lazily_loaded_attributes = self.column_names - %w(id code)
        lazily_loaded_attributes.each do |attribute|
          obj.instance_eval <<-END, __FILE__, __LINE__ + 1
            class << self
              def #{attribute}
                self.class.find(self.id).#{attribute}
              end
            end
          END
        end
      end

      @__loading_ref_data = false
      reference_data
    end

    def install_dynamic_loading_hook
      # We need to hook the class method_missing method to try reloading the
      # reference data when running in test mode. This is because we are loading
      # the reference data from fixtures and they aren't in the database
      # when this code is evaluated. Therefore, we will dynamically load it
      # on first access.
      logger.debug {"Installing dynamic loading hook on #{self}"}
      class_eval <<-END, __FILE__, __LINE__ + 1
        class << self
          def method_missing_with_load_ref_data_call(method, *args)
            unless loaded? || loading?
              self.all_by_code
              if respond_to?(method)
                return send(method, *args)
              end
            end

            method_missing_without_load_ref_data_call(method, *args)
          end

          alias :method_missing_without_load_ref_data_call :method_missing
          alias :method_missing :method_missing_with_load_ref_data_call
        end

        def method_missing_with_load_ref_data_call(method, *args)
          unless self.class.loaded? || self.class.loading?
            self.class.all_by_code
            if respond_to?(method)
              return send(method, *args)
            end
          end

          method_missing_without_load_ref_data_call(method, *args)
        end

        alias :method_missing_without_load_ref_data_call :method_missing
        alias :method_missing :method_missing_with_load_ref_data_call
      END
    end
  end

  module InstanceMethods
    def respond_to?(symbol, include_private=false)
      # Make sure all dynamic methods have been generated
      self.class.all_by_code
      super(symbol, include_private)
    end

    private
      def fail_on_destroy
        raise 'Reference data types cannot be destroyed through the application. ' +
          'Delete the data in the database and modify the application instead.'
      end

      def fail_on_create
        raise 'Reference data types cannot be created through the application. ' +
          'Create the data in the database and modify the application instead.'
      end

      def fail_on_modifying_code
        if code_changed?
          raise 'Referene data codes cannot be changed through the application. ' +
            'Change the data in the database and modify the application instead.'
        end
      end
  end
end

ActiveRecord::Base.class_eval { include ActsAsReferenceData }
