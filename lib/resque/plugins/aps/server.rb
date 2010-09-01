
# Extend Resque::Server to add tabs
module Resque
  module Plugins
    module Aps
  
      module Server

        def self.included(base)

          base.class_eval do

            get "/aps" do
              # Is there a better way to specify alternate template locations with sinatra?
              erb File.read(File.join(File.dirname(__FILE__), 'server/views/aps_applications.erb'))
            end

            get "/aps/:application_name" do
              # Is there a better way to specify alternate template locations with sinatra?
              erb File.read(File.join(File.dirname(__FILE__), 'server/views/notifications.erb'))
            end
        
            post "/aps/:application_name" do
              Resque.enqueue(Resque::Plugins::Aps::Application, params[:application_name])
              redirect url("/aps")
            end
          end

        end

        Resque::Server.tabs << 'APS'

      end
  
    end
  end
end