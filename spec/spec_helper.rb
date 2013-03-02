$:.unshift File.expand_path(File.join(__FILE__, '..', '..', 'lib'))

require 'groonga'
require 'tmpdir'

class Groonga::Database
  class << self
    alias create_orig create
  end
end

RSpec.configure do |config|
  config.treat_symbols_as_metadata_keys_with_true_values = true
  config.run_all_when_everything_filtered = true
  config.filter_run :focus

  # Run specs in random order to surface order dependencies. If you find an
  # order dependency and want to debug it, you can fix the order by providing
  # the seed, which is printed after each run.
  #     --seed 1234
  # config.order = 'random'
  #
  config.around(:each) do |example|
    if example.metadata.has_key?(:groonga) && !example.metadata[:groonga]
      example.run
    elsif example.metadata[:groonga] == :dir
      Dir.mktmpdir("matoi_groonga") do |dir|
        @tmpdir = dir
        example.run
      end
    else
      Dir.mktmpdir("matoi_groonga") do |dir|
        setup_mocks_for_rspec
        Groonga::Database.create(path: File.join(dir, 'matoi_groonga'))
        Groonga::Database.stub(create: Groonga::Context.default.database,
                               open:   Groonga::Context.default.database)
        example.run
      end
    end
  end
end
