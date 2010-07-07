require 'openssl'

module ResqueAps
  class Application
    include ResqueAps::Helper
    extend ResqueAps::Helper

    attr_accessor :name, :cert_file, :cert_passwd

    @queue = "apple_push_service"

    def inspect
      "#<#{self.class.name} #{name.inspect}, #{cert_passwd.inspect}, #{cert_file.inspect}>"
    end
    
    def self.perform(*args)
      count = 0
      start = Time.now
      app_name = args[0]
      Resque.aps_application(app_name).socket do |socket, app|
        while true
          n = Resque.dequeue_aps(app_name)
          if n.nil?
            if app.aps_nil_notification_retry? count, start
              next
            else
              break
            end
          end

          app.before_aps_write n
          begin
            socket.write(n.formatted)
            app.after_aps_write n
          rescue
            logger.error application_exception($!) if logger
            app.failed_aps_write n
          end
          count += 1
        end
      end
      logger.info("Sent #{count} #{app_name} notifications in batch over #{Time.now - start} sec.") if logger
    end
    
    #
    # Create the TCP and SSL sockets for sending the notification
    #
    def self.create_sockets(cert_file, passphrase, host, port)
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
    def self.close_sockets(socket, ssl_socket)
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

    def initialize(attributes)
      attributes.each do |k, v|
        respond_to?(:"#{k}=") ? send(:"#{k}=", v) : raise(ResqueAps::UnknownAttributeError, "unknown attribute: #{k}")
      end
    end
    
    def socket(&block)
      logger.debug("resque-aps: ssl_socket(#{name})") if logger
      exc = nil

      socket, ssl_socket = Application.create_sockets(cert_file, cert_passwd, Resque.aps_gateway_host, Resque.aps_gateway_port)

      begin
        ssl_socket.connect
        yield ssl_socket, self if block_given?
      rescue
        exc = application_exception($!)
        if $! =~ /^SSL_connect .* certificate (expired|revoked)/
          notify_aps_admin exc
        end
        raise exc
      ensure
        Application.close_sockets(socket, ssl_socket)
      end

      exc
    end

    def application_exception(exception)
      exc = Exception.new("#{exception} (#{name})")
      exc.set_backtrace(exception.backtrace)
      return exc
    end
    
    def to_hash
      {'name' => name, 'cert_file' => cert_file, 'cert_passwd' => cert_passwd}
    end
    
    def to_json
      to_hash.to_json
    end

    def before_aps_write(notification)
    end

    def after_aps_write(notification)
    end

    def failed_aps_write(notification)
    end

    def notify_aps_admin(exception)
    end

    def aps_nil_notification_retry?(sent_count, start_time)
      false
    end

  end
end