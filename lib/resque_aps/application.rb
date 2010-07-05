module ResqueAps
  class Application
    attr_accessor :name, :cert_file, :cert_passwd

    @queue = "apple_push_service"
    
    def self.perform(*args)
      Resque.aps_application(args[0])
    end
    
    def initialize(attributes)
      attributes.each do |k, v|
        respond_to?(:"#{k}=") ? send(:"#{k}=", v) : raise(UnknownAttributeError, "unknown attribute: #{k}")
      end
    end
    
    #
    # Create the TCP and SSL sockets for sending the notification
    #
    def create_sockets(host, port)
      cert = File.read(cert_file)

      ctx = OpenSSL::SSL::SSLContext.new
      ctx.key = OpenSSL::PKey::RSA.new(cert, passphrase)
      ctx.cert = OpenSSL::X509::Certificate.new(cert)

      s = TCPSocket.new(host, port)
      ssl = OpenSSL::SSL::SSLSocket.new(s, ctx)
      ssl.sync = true

      return s, ssl
    end

    #
    # Close the sockets
    #
    def close_sockets(socket, ssl_socket)
      begin
        if ssl_socket
          ssl_socket.close
        end
      rescue
        Resque.logger.error("#{$!}: #{$!.backtrace.join("\n")}") if Resque.logger
      end

      begin
        if socket
          socket.close
        end
      rescue
        Resque.logger.error("#{$!}: #{$!.backtrace.join("\n")}") if Resque.logger
      end
    end
  end
end