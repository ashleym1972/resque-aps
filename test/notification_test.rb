require File.dirname(__FILE__) + '/test_helper'

context "Resque::Plugins::Aps::Notification" do
  test "has a nice #inspect" do
    n = Resque::Plugins::Aps::Notification.new('application_name' => 'SomeApp', 'device_token' => 'aihdf08u2402hbdfquhiwr', 'payload' => '{"aps": { "alert": "hello"}}')
    assert_equal '#<Resque::Plugins::Aps::Notification "SomeApp", "aihdf08u2402hbdfquhiwr", "{\"aps\": { \"alert\": \"hello\"}}">', n.inspect
  end
end