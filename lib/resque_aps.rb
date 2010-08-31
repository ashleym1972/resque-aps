require 'rubygems'
require 'resque'
require 'logger'
require 'resque/server'
require 'resque_aps/helper'
require 'resque_aps/version'
require 'resque_aps/server'
require 'resque_aps/application'
require 'resque_aps/notification'
require 'resque_aps/feedback'
require 'resque_aps/unknown_attribute_error'

module Resque
  module Plugins
    module Aps

      def logger=(logger)
        @logger = logger
      end
  
      def logger
        unless @logger
          @logger = Logger.new(STDOUT)
          @logger.level = Logger::WARN
        end
        @logger
      end
  
      def aps_gateway_host=(host)
        @aps_gateway_host = host
      end
  
      def aps_gateway_host
        @aps_gateway_host ||= "gateway.sandbox.push.apple.com"
      end
  
      def aps_gateway_port=(port)
        @aps_gateway_port = port
      end
  
      def aps_gateway_port
        @aps_gateway_port ||= 2195
      end
  
      def aps_feedback_host=(host)
        @aps_feedback_host = host
      end
  
      def aps_feedback_host
        @aps_feedback_host ||= "feedback.sandbox.push.apple.com"
      end
  
      def aps_feedback_port=(port)
        @aps_feedback_port = port
      end
  
      def aps_feedback_port
        @aps_feedback_port ||= 2196
      end
  
      def aps_queue_size_upper=(size)
        @aps_queue_size_upper = size
      end
  
      def aps_queue_size_upper
        @aps_queue_size_upper ||= 1000
      end
  
      def aps_application_job_limit=(size)
        @aps_queue_size_upper = size
      end
  
      def aps_application_job_limit
        @aps_application_job_limit ||= 5
      end
  
      def aps_applications_queued_count(application_name)
        redis.get(aps_application_queued_key(application_name)) || 0
      end
  
      def enqueue_aps_application(application_name, override = false)
        count_apps = aps_applications_queued_count(application_name)
        count_not  = aps_notification_count_for_application(application_name)
        if override || count_apps <= 0 || (count_apps < aps_application_job_limit && (count_not > aps_queue_size_upper && count_not % (aps_queue_size_upper / 10) == 0))
          enqueue(Resque::Plugins::Aps::Application, application_name)
          redis.incr(aps_application_queued_key(application_name))
        end
      end
      
      def dequeue_aps_application(application_name)
        redis.decr(aps_application_queued_key(application_name)) if aps_applications_queued_count(application_name) > 0
      end
      
      def enqueue_aps(application_name, notification)
        redis.rpush(aps_application_queue_key(application_name), encode(notification.to_hash))
        enqueue_aps_application(application_name)
        true
      end

      def dequeue_aps(application_name)
        h = decode(redis.lpop(aps_application_queue_key(application_name)))
        return Resque::Plugins::Aps::Notification.new(h) if h
        nil
      end
  
      # Returns the number of queued notifications for a given application
      def aps_notification_count_for_application(application_name)
        redis.llen(aps_application_queue_key(application_name)).to_i
      end

      # Returns an array of queued notifications for the given application
      def aps_notifications_for_application(application_name, start = 0, count = 1)
        r = redis.lrange(aps_application_queue_key(application_name), start, count)
        if r 
          r.map { |h| Resque::Plugins::Aps::Notification.new(decode(h)) }
        else
          []
        end
      end

      def create_aps_application(name, cert_file, cert_passwd = nil)
        redis.set(aps_application_key(name), encode({'name' => name, 'cert_file' => cert_file, 'cert_passwd' => cert_passwd}))
        redis.sadd(:aps_applications, name)
      end
  
      def aps_application(name)
        h = decode(redis.get(aps_application_key(name)))
        return Resque::Plugins::Aps::Application.new(h) if h
        nil
      end
  
      # Returns an array of applications based on start and count
      def aps_application_names(start = 0, count = 1)
        a = redis.smembers(:aps_applications)
        return a if count == 0
        ret = a[start..(start + count)]
        return [] unless ret
        ret
      end

      # Returns the number of application queues
      def aps_applications_count
        redis.smembers(:aps_applications).size
      end

      def aps_application_key(application_name)
        "aps:application:#{application_name}"
      end
  
      def aps_application_queued_key(application_name)
        "#{aps_application_key(application_name)}:queued"
      end
      
      def aps_application_queue_key(application_name)
        "#{aps_application_key(application_name)}:queue"
      end
    end
  end
end

Resque.extend Resque::Plugins::Aps
Resque::Server.class_eval do
  include Resque::Plugins::Aps::Server
end
