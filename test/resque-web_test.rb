require File.dirname(__FILE__) + '/test_helper'

# Pull in the server test_helper from resque
require 'resque/server/test_helper.rb'

context "on GET to /aps" do
  setup { get "/aps" }

  should_respond_with_success
end

context "on GET to /aps with applications" do
  setup do 
    ENV['rails_env'] = 'production'
    Resque.create_aps_application(:some_ivar_application, nil, nil)
    get "/aps"
  end

  should_respond_with_success

  test 'see the applications' do
    assert last_response.body.include?('some_ivar_application')
  end
end

context "on GET to /aps/some_ivar_application" do
  setup do
    ENV['rails_env'] = 'production'
    Resque.create_aps_application(:some_ivar_application, nil, nil)
    get "/aps/some_ivar_application"
    puts last_response.body
  end

  should_respond_with_success
end
