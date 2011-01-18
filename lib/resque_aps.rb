require 'rubygems'
require 'resque'
require 'logger'
require 'resque/server'
require 'resque/plugins/aps'
require 'resque/plugins/aps/helper'
require 'resque/plugins/aps/version'
require 'resque/plugins/aps/server'
require 'resque/plugins/aps/application'
require 'resque/plugins/aps/notification'
require 'resque/plugins/aps/feedback'
require 'resque/plugins/aps/unknown_attribute_error'

Resque.extend Resque::Plugins::Aps
Resque::Server.class_eval do
  include Resque::Plugins::Aps::Server
end
