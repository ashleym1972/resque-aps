require File.dirname(__FILE__) + '/test_helper'

context "Resque::Plugins::Aps" do
  setup do
    Resque.redis.flushall
  end

  # test "needs to infer a queue with enqueue" do
  #   assert_raises Resque::NoQueueError do
  #     Resque.enqueue(SomeJob, 20, '/tmp')
  #   end
  # end

  test "can create an application" do
    assert Resque.create_aps_application('SomeApp', '/var/apps/certificates/someapp.pem')
    assert_equal 1, Resque.aps_applications_count
    assert Resque.create_aps_application('SomeApp2', '/var/apps/certificates/someapp2.pem', 'secret')
    assert_equal 2, Resque.aps_applications_count
  end
  
  test "can get an application" do
    Resque.create_aps_application('SomeApp', '/var/apps/certificates/someapp.pem', 'secret')
    a = Resque.aps_application('SomeApp')
    assert_equal 'SomeApp', a.name
    assert_equal '/var/apps/certificates/someapp.pem', a.cert_file
    assert_equal 'secret', a.cert_passwd
  end
  
  # test "can update an application" do
  # end
  
  test "knows how big the application queue is" do
    assert_equal 0, Resque.aps_applications_count

    Resque.create_aps_application('SomeApp', '/var/apps/certificates/someapp.pem', 'secret')
    assert_equal 1, Resque.aps_applications_count
  end

  test "can get a list of application names" do
    assert Resque.create_aps_application('SomeApp', '/var/apps/certificates/someapp.pem')
    assert Resque.create_aps_application('SomeApp2', '/var/apps/certificates/someapp2.pem', 'secret')
    assert_equal ['SomeApp2', 'SomeApp'], Resque.aps_application_names(0, 2)
  end

  test "can enqueue aps notifications" do
    n = Resque::Plugins::Aps::Notification.new('application_name' => 'SomeApp', 'device_token' => 'aihdf08u2402hbdfquhiwr', 'payload' => '{"aps": { "alert": "hello"}}')
    assert Resque.enqueue_aps('SomeApp', n)
    assert_equal 1, Resque.aps_notification_count_for_application('SomeApp')
    assert Resque.enqueue_aps('SomeApp', n)
    assert_equal 2, Resque.aps_notification_count_for_application('SomeApp')
  end

  test "can dequeue aps notifications" do
    n = Resque::Plugins::Aps::Notification.new('application_name' => 'SomeApp', 'device_token' => 'aihdf08u2402hbdfquhiwr', 'payload' => '{"aps": { "alert": "hello"}}')
    assert Resque.enqueue_aps('SomeApp', n)
    assert_equal 1, Resque.aps_notification_count_for_application('SomeApp')

    nn = Resque.dequeue_aps('SomeApp')

    assert nn
    assert_kind_of Resque::Plugins::Aps::Notification, nn
    assert_equal n.application_name, nn.application_name
    assert_equal n.device_token,     nn.device_token
    assert_equal n.payload,          nn.payload
  end

  test "knows how big the application notification queue is" do
    n = Resque::Plugins::Aps::Notification.new('application_name' => 'SomeApp', 'device_token' => 'aihdf08u2402hbdfquhiwr', 'payload' => '{"aps": { "alert": "hello"}}')
    assert Resque.enqueue_aps('SomeApp', n)
    assert_equal 1, Resque.aps_notification_count_for_application('SomeApp')

    assert Resque.enqueue_aps('SomeApp', n)
    assert_equal 2, Resque.aps_notification_count_for_application('SomeApp')
  end

  test "can get a list of application notifications" do
    n = Resque::Plugins::Aps::Notification.new('application_name' => 'SomeApp', 'device_token' => 'aihdf08u2402hbdfquhiwr', 'payload' => '{"aps": { "alert": "hello"}}')
    assert Resque.enqueue_aps('SomeApp', n)
    assert Resque.enqueue_aps('SomeApp', n)
    assert Resque.enqueue_aps('SomeApp', n)
    assert_equal 3, Resque.aps_notification_count_for_application('SomeApp')
    a = Resque.aps_notifications_for_application('SomeApp', 0, 20)
    assert_equal 3, a.size
  end
end
