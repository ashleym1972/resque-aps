
module ResqueAps

  module ApsHelper

    extend Resque::Helpers

    class << self

      # Runs a named hook, passing along any arguments.
      def run_hook(name, *args)
        return unless hook = Resque.send(name)
        msg = "Running #{name} hook"
        msg << " with #{args.inspect}" if args.any?
        logger.debug msg if logger

        args.any? ? hook.call(*args) : hook.call
      end


    end

  end

end
