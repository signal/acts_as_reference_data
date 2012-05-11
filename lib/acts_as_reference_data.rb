require 'acts_as_reference_data/railtie' if defined?(Rails)
require 'weakref'

# An ActiveRecord extension that allows a model to be marked as reference data.
# Models marked as such will have a number of methods automatically created.
# These methods will only query the database a single time to lookup the data.
module ActsAsReferenceData
  def self.fixture_classes
    ActiveRecord::Base.__reference_data_classes__.select do |klass|
      klass.generated_fixtures
    end
  end

  module ActiveRecordExtension
    # Includes the reference data behavior on this class.
    #
    # There are a few options that can be passed.
    #
    # synonyms:
    #   You can pass a hash of synonyms that should be available for reference
    #   data lookup. This is useful when the code in the database is poorly
    #   named, but you can't change the value.
    #
    #       acts_as_reference_data :synonyms => {:M => :MALE}
    #
    # generated_fixtures:
    #   When true, reference data will be copied from the development database
    #   to the test database before tests are run. The primary key is modified
    #   to align with what would be generated if a fixture file was present
    #   with the fixture name == to the code.
    #
    #   By copying the rows with this modified key, you can set reference data
    #   associations using the same syntax you would use for normal fixtures.
    #
    #       class Gender < ActiveRecord::Base
    #         acts_as_reference_data
    #       end
    #
    #       class Person < ActiveRecord::Base
    #         belongs_to :gender
    #       end
    #
    #       # people.yml
    #       some_guy:
    #         gender: MALE
    #
    def acts_as_reference_data(options = {})
      if options[:synonyms]
        options[:synonyms].each do |real, synonym|
          define_synonym_methods(real, synonym)
        end
      end

      class_eval <<-END, __FILE__, __LINE__ + 1
        before_destroy :fail_on_destroy
        before_create :fail_on_create
        before_save :fail_on_modifying_code

        include ActsAsReferenceData::InstanceMethods
        extend ActsAsReferenceData::ClassMethods

        class_attribute :generated_fixtures

        class << self
          def all_by_code
            @__reference_data__ ||= load_reference_data
          end
        end
      END

      self.generated_fixtures = options.fetch(:generated_fixtures, true)

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

    private
    # Defines alternate methods for the real reference data values. This is
    # useful when the reference data codes are shorten in the datbase, and
    # therefore hard to remember.
    def define_synonym_methods(real, synonym)
      real, synonym = [real, synonym].map(&:to_s)

      class_eval <<-END, __FILE__, __LINE__ + 1
        def self.#{synonym.upcase}                 # def self.MALE
          self.#{real.upcase}                      #   self.M
        end                                        # end

        def #{synonym.downcase}?                   # def male?
          #{real.downcase}?                        #   m?
        end                                        # end
      END
    end
  end

  module ClassMethods
    def [](code)
      if @_ref_data_needs_reload
        self.all_by_code.each do |_, obj|
          obj.reload
        end
        loaded
        @_ref_data_needs_reload = true
      end
      self.all_by_code[code.to_s.upcase]
    end

    def needs_reload
      @_ref_data_needs_reload = true
    end

    # This is a class method that subclasses can override to run additional
    # logic after reference data is loaded from the database. This might be
    # useful to index reference data by an alternate means of looking up the
    # data.
    def loaded
    end

    private
    def load_reference_data
      reference_data = {}
      self.find(:all).each do |data|
        reference_data[data.attributes['code'].upcase] = data
      end

      logger.debug { "Loaded #{reference_data.keys.inspect} for #{self}" }

      reference_data.each do |code,obj|
        define_reference_data_methods(obj)
      end

      loaded

      reference_data
    end

    def define_reference_data_methods(object)
      code = object.code

      class_eval <<-END, __FILE__, __LINE__ + 1
        def self.#{code.upcase}                    # def self.MALE
          self['#{code.upcase}']                   #   self['MALE']
        end                                        # end

        def #{code.downcase}?                      # def male?
          code.upcase == '#{code.upcase}'          #   code.upcase == 'MALE'
        end                                        # end
      END
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

ActiveRecord::Base.class_eval { extend ActsAsReferenceData::ActiveRecordExtension }
