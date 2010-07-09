require 'timeout'

module ResqueAps
  class Feedback
    include ResqueAps::Helper
    extend ResqueAps::Helper

    attr_accessor :application_name, :device_token, :received_at

    def initialize(attributes)
      attributes.each do |k, v|
        respond_to?(:"#{k}=") ? send(:"#{k}=", v) : raise(ResqueAps::UnknownAttributeError, "unknown attribute: #{k}")
      end
    end
        
    def inspect
      "#<#{self.class.name} #{application_name.inspect}, #{device_token.inspect}, #{received_at.inspect}>"
    end
    
    def to_s
      "#{application_name} #{received_at} #{device_token}"
    end

    def to_hash
      {:application_name => application_name, :device_token => device_token, :received_at => received_at}
    end

    def self.read_feedback(ssl_socket, application_name, product_id)
        data_str = ssl_socket.read(4)
        return nil unless data_str
        data_ary = data_str.unpack('N')
        return nil unless data_ary && data_ary[0]
        time     = Time.at(data_ary[0])

        data_str = ssl_socket.read(2)
        return nil unless data_str
        data_ary = data_str.unpack('n')
        return nil unless data_ary && data_ary[0]
        tl       = data_ary[0]

        data_str = ssl_socket.read(tl)
        return nil unless data_str
        data_ary = data_str.unpack('H*')
        return nil unless data_ary && data_ary[0]
        token    = data_ary[0]

        feedback = Feedback.new({:received_at => time, :device_token => token, :application_name => application_name})
        return feedback
    end

    #
    # Perform a Feedback check on the APN server, for the given app key (which must be the first argument)
    #
    def self.perform(*args)
      app_name = args[0]
      start    = Time.now
      count    = 0
      appl     = Resque.aps_application(app_name)

      return unless appl
      
      appl.socket(nil, nil, Resque.aps_feedback_host, Resque.aps_feedback_port) do |socket, app|
        begin
          logger.debug("Feedback: Reading feedbacks for #{app_name}.") if logger
          timeout(5) do
            until socket.eof?
              app.before_aps_read
              feedback = read_feedback(ssl_socket, app_name, product_id)
              if feedback
                count += 1
                app.after_app_read(feedback)
              else
                app.aps_read_failed
              end
            end
          end
        rescue
          logger.error Application.application_exception($!, app_name) if logger
          app.aps_read_error(Application.application_exception($!, app_name))
        end
      end
      logger.info("Read #{count} #{app_name} feedbacks over #{Time.now - start} sec.") if logger
    end

  end
end