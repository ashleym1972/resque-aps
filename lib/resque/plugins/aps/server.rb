
# Extend Resque::Server to add tabs
module Resque
  module Plugins
    module Aps
  
      module Server

        def self.included(base)

          base.class_eval do

            aps_dir = File.dirname(File.expand_path(__FILE__)) + "/server/views"

            get "/aps" do
              # Is there a better way to specify alternate template locations with sinatra?
              erb File.read("#{aps_dir}/aps_applications.erb"), :resque => Resque
            end

            get "/aps/:application_name" do
              # Is there a better way to specify alternate template locations with sinatra?
              erb File.read("#{aps_dir}/notifications.erb"), :resque => Resque
            end
        
            post "/aps/:application_name" do
              Resque.enqueue(Resque::Plugins::Aps::Application, params[:application_name])
              redirect url("/aps?page_size=0")
            end
            
            post "/aps/:application_name/reset" do
              Resque.redis.set(Resque.aps_application_queued_key(params[:application_name]), 0)
              redirect url("/aps?page_size=0")
            end
            
            post "/aps/:application_name/delete" do
              Resque.delete_aps_application(params[:application_name])
              redirect url("/aps?page_size=0")
            end
          end

        end

        Resque::Server.tabs << 'APS'

      end
  
    end
  end
end