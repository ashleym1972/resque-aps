require 'rubygems'
require 'resque'
require 'resque/server'
require 'resque_aps/version'
require 'resque/aps_helper'
require 'resque_aps/server'
require 'resque_aps/application'
require 'resque_aps/notification'

module ResqueAps

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
    @aps_queue_size_upper ||= 0
  end
  
  def enqueue_aps(application_name, notification)
    count = aps_notification_count_for_application(application_name)
    redis.rpush(aps_application_queue_key(application_name), notification.encode)
    enqueue(ResqueAps::Application, application_name) if count <= aps_queue_size_lower || count >= aps_queue_size_upper
  end

  # Returns the number of queued notifications for a given application
  def aps_notification_count_for_application(application_name)
    redis.llen(aps_application_queue_key(application_name))
  end

  # Returns an array of queued notifications for the given application
  def aps_notifications_for_application(application_name, start = 1, count = 1)
    r = list_range(aps_application_queue_key(application_name), start, count)
    r = r.nil? ? [] : [r] if 1 == count
    r
  end

  def create_aps_application(name, cert_file, cert_passwd)
    redis.set(aps_application_key(name), encode({'name' => name, 'cert_file' => cert_file, 'cert_passwd' => cert_passwd}))
    redis.sadd(:aps_applications, name)
  end
  
  def aps_application(name)
    decode(redis.get(aps_application_key(name)))
  end
  
  # Returns an array of applications based on start and count
  def aps_application_names(start = 1, count = 1)
    redis.smembers(:aps_applications)[start..(start + count)]
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
