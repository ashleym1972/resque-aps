require File.dirname(__FILE__) + '/test_helper'

context "Resque::Plugins::Aps::Application" do
  test "can perform" do
    Resque.create_aps_application('TestApp', File.dirname(__FILE__) + "/../test-dev.pem", nil)
    Resque::Plugins::Aps::Feedback.perform('TestApp')
  end
end