require File.dirname(__FILE__) + '/test_helper'

# Pull in the server test_helper from resque
require 'resque_aps/server/test_helper.rb'

context "on GET to /aps" do
  setup { get "/aps" }

  should_respond_with_success
end

context "on GET to /aps with applications" do
  setup do 
    Resque.redis.flushall
    Resque.create_aps_application(:some_ivar_application, nil, nil)
    Resque.create_aps_application(:someother_ivar_application, nil, nil)
    get "/aps"
  end

  should_respond_with_success

  test 'see the applications' do
    assert last_response.body.include?('some_ivar_application')
    assert last_response.body.include?('someother_ivar_application')
  end
end

context "on GET to /aps/some_ivar_application" do
  setup do
    Resque.redis.flushall
    Resque.create_aps_application(:some_ivar_application, nil, nil)
    n = Resque::Plugins::Aps::Notification.new('application_name' => 'some_ivar_application', 'device_token' => 'aihdf08u2402hbdfquhiwr', 'payload' => '{"aps": { "alert": "hello"}}')
    assert Resque.enqueue_aps(:some_ivar_application, n)
    assert Resque.enqueue_aps(:some_ivar_application, n)
    assert Resque.enqueue_aps(:some_ivar_application, n)
    assert Resque.enqueue_aps(:some_ivar_application, n)
    get "/aps/some_ivar_application"
  end

  should_respond_with_success

  test 'see the applications' do
    assert last_response.body.include?('some_ivar_application')
  end
end
