require File.dirname(__FILE__) + '/test_helper'

context "ResqueAps::Application" do
  test "has a nice #inspect" do
    n = ResqueAps::Application.new('name' => 'SomeApp', 'cert_file' => '/var/apps/certificates/some_app.pem', 'cert_passwd' => 'hello')
    assert_equal '#<ResqueAps::Application "SomeApp", "hello", "/var/apps/certificates/some_app.pem">', n.inspect
  end
end