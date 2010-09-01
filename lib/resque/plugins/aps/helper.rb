
module Resque
  module Plugins
    module Aps
      module Helper
        extend Resque::Helpers

        def logger
          Resque.logger
        end

      end
    end
  end
end
