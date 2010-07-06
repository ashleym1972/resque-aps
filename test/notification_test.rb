require File.dirname(__FILE__) + '/test_helper'

context "ResqueAps::Notification" do
  test "has a nice #inspect" do
    n = ResqueAps::Notification.new('application_name' => 'SomeApp', 'device_token' => 'aihdf08u2402hbdfquhiwr', 'payload' => '{"aps": { "alert": "hello"}}')
    assert_equal '#<ResqueAps::Notification "SomeApp", "aihdf08u2402hbdfquhiwr", "{\"aps\": { \"alert\": \"hello\"}}">', n.inspect
  end
end