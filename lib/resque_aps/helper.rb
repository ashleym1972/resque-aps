
module ResqueAps
  module Helper
    extend Resque::Helpers

    def logger
      Resque.logger
    end

  end
end
