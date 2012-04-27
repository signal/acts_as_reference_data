require 'test_helper'

class ActsAsReferenceDataTest < ActiveSupport::TestCase

  # Can't use transactional fixtures in this test case because DDL statements
  # are incompatible with them.
  self.use_transactional_fixtures = false

  def setup
    ActiveRecord::Base.connection.create_table('foo_types') do |t|
      t.column 'code', :string
      t.column 'description', :string
    end
    ActiveRecord::Base.connection.insert("INSERT INTO foo_types(code, description) VALUES('bar', 'bar type')")
    ActiveRecord::Base.connection.insert("INSERT INTO foo_types(code, description) VALUES('baz', 'baz type')")

    define_test_class
  end

  def teardown
    unload_test_class
    ActiveRecord::Base.connection.drop_table('foo_types')
  end

  def test_aaa_static_lookup
    assert_equal 1, FooType.BAR.id
  end

  def test_can_reload_reference_data
    ActiveRecord::Base.connection.insert("INSERT INTO foo_types(code, description) VALUES('bop', 'bop type')")
    FooType.reload_reference_data
    assert_not_nil FooType.BOP
  end

  #def test_loading_independent_between_tests
  #  ActiveRecord::Base.connection.insert("INSERT INTO foo_types(code, description) VALUES('bop', 'bop type')")
  #  assert_not_nil FooType.BOP
  #end

  def test_type_interegation_methods
    assert FooType.BAR.bar?
    assert !FooType.BAR.baz?

    assert FooType.BAZ.baz?
    assert !FooType.BAZ.bar?
  end

  def test_type_interagation_methods_when_finding_by_primary_key
    assert FooType.find(1).bar?
    assert !FooType.find(1).baz?

    assert FooType.find(2).baz?
    assert !FooType.find(2).bar?
  end

  def test_respond_to_when_finding_by_primary_key
    assert FooType.find(1).respond_to?(:bar?)
    assert FooType.find(1).respond_to?(:baz?)
  end

  def test_class_method_all_by_code
    assert_equal({'BAR' => FooType.BAR, 'BAZ' => FooType.BAZ}, FooType.all_by_code)
  end

  def test_cached_object_only_has_all_attributes_loaded
    assert_not_nil FooType.BAR.id
    assert_not_nil FooType.BAR.code
    assert_not_nil FooType.BAR.description

    assert_not_nil FooType['BAZ'].id
    assert_not_nil FooType['BAZ'].code
    assert_not_nil FooType['BAZ'].description
  end

  def test_reference_data_objects_cannot_be_destroyed
    assert_raise(RuntimeError) { FooType.BAR.destroy }
  end

  def test_reference_data_objects_cannot_be_created
    assert_raise(RuntimeError) { FooType.create!(:code => 'bop') }
  end

  def test_reference_data_objects_cannot_have_their_code_changed
    assert_raise(TypeError) { FooType.BAR.update_attribute(:code, 'oops') }
  end

  def test_can_get_references_to_all_reference_data_classes
    assert ActiveRecord::Base.__reference_data_classes__.include?(FooType)
  end

  private

  def define_test_class
    self.class.class_eval <<-END
      class FooType < ActiveRecord::Base
        acts_as_reference_data
      end
    END
  end

  def unload_test_class
    self.class.class_eval do
      remove_const('FooType')
    end
  end

end
