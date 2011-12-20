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
        (redis.get(Resque.aps_application_queued_key(name)) || 0).to_i
      end

      # Increase the count of queued application workers
      def enqueue_aps_application(application_name, override = false)
        res = redis.incr(aps_application_queued_key(application_name))
      end

      # Decrease the count of queued application workers
      def dequeue_aps_application(application_name)
        res = redis.decr(aps_application_queued_key(application_name))
      end

      # Push the given notification onto the given application queue
      # returns true
      def enqueue_aps(application_name, notification)
        create_aps_application(application_name, nil, nil) unless aps_application_exists?(application_name)
        redis.rpush(aps_application_queue_key(application_name), encode(notification.to_hash))
        if Resque.inline?
          Resque::Plugins::Aps::Application.perform(application_name, false)
        end
        true
      end

      # Pop the oldest notification off the given application queue
      # returns nil - if there are none on the queue
      def dequeue_aps(application_name)
        h = decode(redis.lpop(aps_application_queue_key(application_name)))
        h ? Resque::Plugins::Aps::Notification.new(h) : nil
      end


      # Age of the oldest notification in the given application queue, in seconds
      # returns 0 - if there are no notifications on the queue or the oldest has no create time
      def aps_age(application_name)
        h = decode(redis.lindex(aps_application_queue_key(application_name), 0))
        res = h ? h['created_at'] ? Time.now.utc - Time.parse(h['created_at']) : 0 : 0
        return res
      end

      # Returns the number of queued notifications for a given application
      def aps_notification_count_for_application(application_name)
        redis.llen(aps_application_queue_key(application_name)).to_i
      end

      # Returns an array of queued notifications for the given application
      def aps_notifications_for_application(application_name, start = 0, count = 1)
        r = redis.lrange(aps_application_queue_key(application_name), start, count)
        r ? r.map { |h| Resque::Plugins::Aps::Notification.new(decode(h)) } : []
      end

      def create_aps_application(name, cert_file, cert_passwd = nil)
        redis.set(aps_application_key(name), encode({'name' => name, 'cert_file' => cert_file, 'cert_passwd' => cert_passwd}))
        redis.sadd(:aps_applications, name)
      end

      def delete_aps_application(name)
        redis.del(aps_application_key(name))
        redis.srem(:aps_applications, name)
        redis.del(aps_application_queue_key(name))
      end

      def aps_application_exists?(name)
        redis.exists(aps_application_key(name)) == 1
      end

      def aps_application(name)
        h = decode(redis.get(aps_application_key(name)))
        h ? Resque::Plugins::Aps::Application.new(h) : nil
      end
  
      # Returns an array of applications based on start and count
      def aps_application_names(start = 0, count = 1)
        a = redis.smembers(:aps_applications)
        return a if count == 0
        a[start..(start + count)] || []
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
