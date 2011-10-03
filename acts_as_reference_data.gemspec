$:.push File.expand_path("../lib", __FILE__)

require "acts_as_reference_data/version"

Gem::Specification.new do |s|
  s.name        = "acts_as_reference_data"
  s.version     = ActsAsReferenceData::VERSION
  s.authors     = ["Doug Barth"]
  s.email       = ["doug@signalhq.com"]
  s.summary     = "Summary of ActsAsReferenceData."
  s.description = "Description of ActsAsReferenceData."

  s.files = Dir["{app,config,db,lib}/**/*"] + ["MIT-LICENSE", "Rakefile", "README.rdoc"]
  s.test_files = Dir["test/**/*"]

  s.add_dependency "rails", "~> 3.1.0"

  s.add_development_dependency "sqlite3"
end
