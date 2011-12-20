require File.dirname(__FILE__) + '/test_helper'

context "Resque::Plugins::Aps::Application" do
  test "has a nice #inspect" do
    n = Resque::Plugins::Aps::Application.new('name' => 'SomeApp', 'cert_file' => '/var/apps/certificates/some_app.pem', 'cert_passwd' => 'hello')
    assert_equal '#<Resque::Plugins::Aps::Application "SomeApp", "hello", "/var/apps/certificates/some_app.pem">', n.inspect
  end

  test "can create and close sockets" do
    cert = File.read(File.dirname(__FILE__) + "/../test-dev.pem")
    socket, ssl = Resque::Plugins::Aps::Application.create_sockets(cert, nil, Resque.aps_gateway_host, Resque.aps_gateway_port)
    Resque::Plugins::Aps::Application.close_sockets(socket, ssl)
  end

  test "can run socket block" do
    a = Resque::Plugins::Aps::Application.new(:name => "TestApp", :cert_file => File.dirname(__FILE__) + "/../test-dev.pem")
    a.socket do |s, a|
    end
  end
  
  test "can perform" do
    n = Resque::Plugins::Aps::Notification.new('application_name' => 'TestApp', 'device_token' => '3ECA0F9A3405B980A88A61A1556AF8B7F1DF5F7F109E1476A781E8220C4FE561', 'payload' => '{"aps": { "alert": "hello"}}')
    assert Resque.enqueue_aps('TestApp', n)
    Resque.create_aps_application('TestApp', File.dirname(__FILE__) + "/../test-dev.pem", nil)
    Resque::Plugins::Aps::Application.perform('TestApp')
    assert_equal 0, Resque.aps_notification_count_for_application('TestApp')
  end

  test "has a good c2dm flag" do
    a = Resque::Plugins::Aps::Application.new('name' => 'SomeApp', 'cert_file' => '/var/apps/certificates/some_app.pem', 'cert_passwd' => 'hello', 'os' => 'Android')
    assert a.c2dm?
    a = Resque::Plugins::Aps::Application.new('name' => 'SomeApp', 'cert_file' => '/var/apps/certificates/some_app.pem', 'cert_passwd' => 'hello')
    assert !a.c2dm?
    a = Resque::Plugins::Aps::Application.new('name' => 'SomeApp', 'cert_file' => '/var/apps/certificates/some_app.pem', 'cert_passwd' => 'hello', 'os' => 'iOS')
    assert !a.c2dm?
  end

  context "ApplicationWithHooks" do
    module Resque::Plugins::Aps
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
      n = Resque::Plugins::Aps::Notification.new('application_name' => 'TestApp', 'device_token' => '3ECA0F9A3405B980A88A61A1556AF8B7F1DF5F7F109E1476A781E8220C4FE561', 'payload' => '{"aps": { "alert": "hello"}}')
      assert Resque.enqueue_aps('TestApp', n)
      Resque.create_aps_application('TestApp', File.dirname(__FILE__) + "/../test-dev.pem", nil)
      Resque::Plugins::Aps::Application.perform('TestApp')
      assert_equal 0, Resque.aps_notification_count_for_application('TestApp')
    end

    test "can perform with failure logging hooks" do
      n = Resque::Plugins::Aps::Notification.new('application_name' => 'TestApp', 'device_token' => 'aihdf08u2402hbdfquhiwr', 'payload' => '{"aps": { "alert": "hello"}}')
      assert Resque.enqueue_aps('TestApp', n)
      Resque.create_aps_application('TestApp', File.dirname(__FILE__) + "/../test-dev.pem", nil)
      Resque::Plugins::Aps::Application.perform('TestApp')
      assert_equal 0, Resque.aps_notification_count_for_application('TestApp')
    end
  end
end