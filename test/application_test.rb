require File.dirname(__FILE__) + '/test_helper'

context "ResqueAps::Application" do
  test "has a nice #inspect" do
    n = ResqueAps::Application.new('name' => 'SomeApp', 'cert_file' => '/var/apps/certificates/some_app.pem', 'cert_passwd' => 'hello')
    assert_equal '#<ResqueAps::Application "SomeApp", "hello", "/var/apps/certificates/some_app.pem">', n.inspect
  end

  test "can create and close sockets" do
    cert = File.read(File.dirname(__FILE__) + "/../test-dev.pem")
    socket, ssl = ResqueAps::Application.create_sockets(cert, nil, Resque.aps_gateway_host, Resque.aps_gateway_port)
    ResqueAps::Application.close_sockets(socket, ssl)
  end

  test "can run socket block" do
    a = ResqueAps::Application.new(:name => "TestApp", :cert_file => File.dirname(__FILE__) + "/../test-dev.pem")
    a.socket do |s, a|
    end
  end
  
  test "can perform" do
    n = ResqueAps::Notification.new('application_name' => 'TestApp', 'device_token' => 'aihdf08u2402hbdfquhiwr', 'payload' => '{"aps": { "alert": "hello"}}')
    assert Resque.enqueue_aps('TestApp', n)
    Resque.create_aps_application('TestApp', File.dirname(__FILE__) + "/../test-dev.pem", nil)
    ResqueAps::Application.perform('TestApp')
  end

  context "ApplicationWithHooks" do
    module ResqueAps
      class Application
        def before_aps_write(notification)
          logger.debug "before_aps_write #{notification.inspect}"
        end

        def after_aps_write(notification)
          logger.debug "after_aps_write #{notification.inspect}"
        end

        def failed_aps_write(notification, exception)
          logger.debug "failed_aps_write #{notification.inspect}"
        end

        def notify_aps_admin(exception)
          logger.debug "notify_aps_admin #{exception}"
        end

        def aps_nil_notification_retry?(sent_count, start_time)
          logger.debug "aps_nil_notification_retry #{sent_count}"
          false
        end
      end
    end
    
    test "can perform with logging hooks" do
      n = ResqueAps::Notification.new('application_name' => 'TestApp', 'device_token' => 'aihdf08u2402hbdfquhiwr', 'payload' => '{"aps": { "alert": "hello"}}')
      assert Resque.enqueue_aps('TestApp', n)
      Resque.create_aps_application('TestApp', File.dirname(__FILE__) + "/../test-dev.pem", nil)
      ResqueAps::Application.perform('TestApp')
    end
  end
end