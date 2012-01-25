task :load_reference_data => :environment do
  ActiveRecord::Base.establish_connection(ActiveRecord::Base.configurations['test'])
  Dir["#{Rails.root}/app/models/reference_data/**/*.rb"].each {|f| require f}
  require 'active_record/fixtures'

  ActiveRecord::Base.connection.disable_referential_integrity do
    ActiveRecord::Base.transaction do
      ActiveRecord::Base.__reference_data_classes__.each do |ref_data_class|
        ref_data_class.delete_all

        dev_ref_data_class = Class.new(ref_data_class)
        dev_ref_data_class.const_set("Dev", dev_ref_data_class)
        dev_ref_data_class.class_eval do
          set_table_name ref_data_class.table_name.sub(/.*\./, '')
          establish_connection(:development)
        end

        ref_data_class.class_eval do
          def fail_on_create; end
          def fail_on_modifying_code; end
        end

        dev_ref_data_class.find_each do |dev_ref_data|
          attributes = dev_ref_data.attributes.dup
          attributes.stringify_keys!
          attributes.delete('id')

          ref_data = ref_data_class.new(attributes)
          ref_data.id = ActiveRecord::Fixtures.identify(attributes['code'])
          ref_data.save!
        end
      end
    end
  end
end

Rake::Task['db:test:prepare'].enhance do
  Rake::Task['load_reference_data'].invoke
end
