require 'test_helper'

class IsolationTest < ActiveSupport::TestCase
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

    ActiveRecord::Base.connection.create_table('goo_types') do |t|
      t.column 'code', :string
      t.column 'description', :string
    end
    ActiveRecord::Base.connection.insert("INSERT INTO goo_types(code, description) VALUES('gar', 'gar type')")
    ActiveRecord::Base.connection.insert("INSERT INTO goo_types(code, description) VALUES('gaz', 'gaz type')")

    define_test_class('FooType')
    define_test_class('GooType')
  end

  def teardown
    unload_test_class('FooType')
    unload_test_class('GooType')
    ActiveRecord::Base.connection.drop_table('foo_types')
    ActiveRecord::Base.connection.drop_table('goo_types')
  end

  test "accessor methods are not leaked between classes" do
    assert FooType.respond_to?('BAR')
    assert FooType.respond_to?('BAZ')

    assert !FooType.respond_to?('GAR')
    assert !FooType.respond_to?('GAZ')
  end

  test "object tests are not leaked between classes" do
    assert FooType.BAR.respond_to?('bar?')
    assert FooType.BAR.respond_to?('baz?')

    assert !FooType.BAR.respond_to?('gar?')
    assert !FooType.BAR.respond_to?('gaz?')
  end

  private

  def define_test_class(klass)
    self.class.class_eval <<-END
      class #{klass} < ActiveRecord::Base
        acts_as_reference_data
      end
    END
  end

  def unload_test_class(klass)
    self.class.class_eval do
      remove_const(klass)
    end
  end
end
