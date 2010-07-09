require File.dirname(__FILE__) + '/test_helper'

context "ResqueAps::Application" do
  test "can perform" do
    Resque.create_aps_application('TestApp', File.dirname(__FILE__) + "/../test-dev.pem", nil)
    ResqueAps::Feedback.perform('TestApp')
  end
end