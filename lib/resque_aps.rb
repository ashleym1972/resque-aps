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

module ResqueAps

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
  
  def aps_queue_size_lower=(size)
    @aps_queue_size_lower = size
  end
  
  def aps_queue_size_lower
    @aps_queue_size_lower ||= 0
  end
  
  def aps_queue_size_upper=(size)
    @aps_queue_size_upper = size
  end
  
  def aps_queue_size_upper
    @aps_queue_size_upper ||= 500
  end
  
  def enqueue_aps(application_name, notification)
    count = aps_notification_count_for_application(application_name)
    redis.rpush(aps_application_queue_key(application_name), encode(notification.to_hash))
    enqueue(ResqueAps::Application, application_name) if count <= aps_queue_size_lower || count >= aps_queue_size_upper
    true
  end

  def dequeue_aps(application_name)
    h = decode(redis.lpop(aps_application_queue_key(application_name)))
    return ResqueAps::Notification.new(h) if h
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
      r.map { |h| ResqueAps::Notification.new(decode(h)) }
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
    return ResqueAps::Application.new(h) if h
    nil
  end
  
  # Returns an array of applications based on start and count
  def aps_application_names(start = 0, count = 1)
    a = redis.smembers(:aps_applications)
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
  
  def aps_application_queue_key(application_name)
    "#{aps_application_key(application_name)}:queue"
  end
end

Resque.extend ResqueAps
Resque::Server.class_eval do
  include ResqueAps::Server
end
