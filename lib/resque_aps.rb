require 'rubygems'
require 'resque'
require 'resque/server'
require 'resque/aps_helper'
require 'resque_aps/version'
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
  
  def before_aps_write(&block)
    block ? (@before_aps_write = block) : @before_aps_write
  end

  # Set a proc that will be called in the job process before the
  # worker writes an aps notification. Passed the notification object.
  def before_aps_write=(before_aps_write)
    @before_aps_write = before_aps_write
  end
  
  def after_aps_write(&block)
    block ? (@after_aps_write = block) : @after_aps_write
  end

  # Set a proc that will be called in the job process after the
  # worker writes an aps notification. Passed the notification object.
  def after_aps_write=(after_aps_write)
    @after_aps_write = after_aps_write
  end
  
  def failed_aps_write(&block)
    block ? (@after_aps_write = block) : @after_aps_write
  end

  # Set a proc that will be called in the job process if an exception
  # is raised while writing the aps notification. Passed the notification object.
  def failed_aps_write=(after_aps_write)
    @after_aps_write = after_aps_write
  end
  
  def notify_aps_admin(&block)
    block ? (@notify_aps_admin = block) : @notify_aps_admin
  end

  # Set a proc that will be called in the job process if an
  # expired or revoked certificate exception is raised. Passed the exception object.
  def notify_aps_admin=(notify_aps_admin)
    @notify_aps_admin = notify_aps_admin
  end
  
  def aps_nil_notification_retry(&block)
    block ? (@aps_nil_notification_retry = block) : @aps_nil_notification_retry
  end

  # Set a proc that will be called in the job process
  # if the dequeue_aps call returns nil which will return a boolean
  # which indicates if the job should retry the dequeue. This
  # proc should include any sleep needed. Passed the count and start time.
  def aps_nil_notification_retry=(aps_nil_notification_retry)
    @aps_nil_notification_retry = aps_nil_notification_retry
  end
  
  def enqueue_aps(application_name, notification)
    count = aps_notification_count_for_application(application_name)
    push(aps_application_queue_key(application_name), notification.to_hash)
    enqueue(ResqueAps::Application, application_name) if count <= aps_queue_size_lower || count >= aps_queue_size_upper
  end

  def dequeue_aps(application_name)
    h = pop(aps_application_queue_key(application_name))
    return ResqueAps::Notification.new(h) if h
    nil
  end
  
  # Returns the number of queued notifications for a given application
  def aps_notification_count_for_application(application_name)
    size(aps_application_queue_key(application_name))
  end

  # Returns an array of queued notifications for the given application
  def aps_notifications_for_application(application_name, start = 0, count = 1)
    r = peek(aps_application_queue_key(application_name), start, count)
    if r 
      r.map { |h| ResqueAps::Notification.new(h) }
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
