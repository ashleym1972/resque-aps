resque-aps
===============

Resque-Aps is an extension to [Resque](http://github.com/defunkt/resque)
that adds shortcuts to send notifications to Apple's Push System.

Installation and integration with callbacks
--------------------------------------

To install:

    gem install resque-aps

You'll need to add this to your Rails rakefile to see the queue lengths:

    require 'resque/plugins/aps/tasks'
    task "resque:setup" => :environment

    $ rake resque:aps:queue_lengths 

I use this to monitor the system in nagios.

To extend the system create an initializer:

    require 'resque_aps'

    Resque.aps_gateway_host = AppConfig.apn_gateway_host
    Resque.aps_gateway_port = AppConfig.apn_gateway_port
    Resque.aps_feedback_host = AppConfig.apn_feedback_host
    Resque.aps_feedback_port = AppConfig.apn_feedback_port

    module Resque::Plugins::Aps
      class Application
        def after_aps_write(notification)
          logger.info("Sent Notification [#{notification.application_name}] [#{notification.device_token}] [#{notification.payload}]") if logger
        end

        # It probably failed because there is something wrong with the device token
        # do not requeue.
        def failed_aps_write(notification, exception)
          logger.error "failed_aps_write: #{notification.inspect} - #{exception}"
          logger.error exception.backtrace.join("\n")
        end

        # Something is probably wrong with the certificate
        def notify_aps_admin(exception)
          # Notify once a minute
          unless Rails.cache.read("push_certificate:notify_admin:#{name}")
            logger.error("notification: #{exception.message}")
            # Email error to someone
            Rails.cache.write("push_certificate:notify_admin:#{name}", "true", :expires_in => 60)
          end
        rescue
          logger.error("#{$!} (#{name}): #{$!.backtrace.join("\n")}")
        end

        def aps_nil_notification_retry?(sent_count, start_time)
          # Live forever
          sleep 1
          true
          # Or not
          #false
        end

        def after_aps_read(feedback)
          # Remove the device token from the system for this application so we don't send to it anymore
          # feedback.application_name, feedback.device_token
        end
      end
    end


Plagurism alert
---------------

This was intended to be an extension to resque and was based heavily on resque-scheduler,
which resulted in a lot of the code looking very similar. One massive departure is the
use of logging which resque and resque-scheduler do not use but I do.


Contributing
------------

For bugs or suggestions, please just open an issue in github.
