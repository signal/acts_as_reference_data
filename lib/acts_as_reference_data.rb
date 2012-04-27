require 'acts_as_reference_data/railtie' if defined?(Rails)
require 'weakref'

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

      @@__reference_data_classes__ ||= Set.new
      @@__reference_data_classes__ << WeakRef.new(self)

      all_by_code
    end

    def __reference_data_classes__
      @@__reference_data_classes__ ||= Set.new
      @@__reference_data_classes__.reject! {|x| !x.weakref_alive? }
      @@__reference_data_classes__.map {|x| x.__getobj__ }
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

    def reload_reference_data
      reset
      all_by_code
    end

    private
    def load_reference_data
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

          def #{code.downcase}?
            code.upcase == '#{code}'
          end
        END
      end

      reference_data
    end
  end

  module InstanceMethods
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
          raise 'Reference data codes cannot be changed through the application. ' +
            'Change the data in the database and modify the application instead.'
        end
      end
  end
end

ActiveRecord::Base.class_eval { include ActsAsReferenceData }
