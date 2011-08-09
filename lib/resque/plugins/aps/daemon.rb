require 'logger'

module Resque
  module Plugins
    module Aps
      class Daemon
        include Resque::Plugins::Aps::Helper
        extend Resque::Plugins::Aps::Helper

        class << self

          # Schedule all jobs and continually look for delayed jobs (never returns)
          def run
            # trap signals
            register_signal_handlers

            # Now start the scheduling part of the loop.
            loop do
              handle_aps_queues(30)
              poll_sleep
            end

            # never gets here.
          rescue
            logger.error "#{$!}: #{$!.backtrace.join("\n")}"
          end

          def handle_aps_queues(max_age = 60)
            Resque.aps_application_names(0, 0).each do |app_name|
              count_not = Resque.aps_notification_count_for_application(app_name)
              if count_not > 0
                count_apps = Resque.aps_applications_queued_count(app_name).to_i
                if count_apps == 0
                  Resque.enqueue(Resque::Plugins::Aps::Application, app_name, true)
                elsif Resque.aps_age(app_name) >= max_age
                  Resque.enqueue(Resque::Plugins::Aps::Application, app_name, false)
                else
                  logger.error "Unable to queue APS application: #{app_name}"
                end
              end
            end
          end

          # For all signals, set the shutdown flag and wait for current
          # poll/enqueing to finish (should be almost istant).  In the
          # case of sleeping, exit immediately.
          def register_signal_handlers
            trap("TERM") { shutdown }
            trap("INT")  { shutdown }
            trap('QUIT') { shutdown } unless defined? JRUBY_VERSION
          end

          def handle_shutdown
            exit if @shutdown
            yield
            exit if @shutdown
          end

          # Sleeps and returns true
          def poll_sleep
            @sleeping = true
            handle_shutdown { sleep 5 }
            @sleeping = false
            true
          end

          # Sets the shutdown flag, exits if sleeping
          def shutdown
            @shutdown = true
            exit if @sleeping
          end

        end
      end
    end
  end
end