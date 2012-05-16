module ActsAsReferenceData
  class Railtie < Rails::Railtie
    rake_tasks do
      Dir[File.join(File.dirname(__FILE__), '../tasks/*.rake')].each { |f| load f }
    end

    config.to_prepare do
      ActsAsReferenceData.load_reference_data!
    end
  end
end

