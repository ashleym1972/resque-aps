require 'rubygems'
require 'resque'
require 'logger'
require 'resque/server'
require 'resque/plugins/aps/aps'
require 'resque/plugins/aps/helper'
require 'resque/plugins/aps/version'
require 'resque/plugins/aps/server'
require 'resque/plugins/aps/application'
require 'resque/plugins/aps/notification'
require 'resque/plugins/aps/feedback'
require 'resque/plugins/aps/unknown_attribute_error'
require 'resque/plugins/aps/c2dm_socket'

Resque.extend Resque::Plugins::Aps
Resque::Server.class_eval do
  include Resque::Plugins::Aps::Server
end
