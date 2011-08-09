require 'openssl'
require 'benchmark'

module Resque
  module Plugins
    module Aps
      class Application
        include Resque::Plugins::Aps::Helper
        extend Resque::Plugins::Aps::Helper

        attr_accessor :name, :cert_file, :cert_passwd

        @queue   = "apple_push_service"
        @@CAFile = nil

        def inspect
          "#<#{self.class.name} #{name.inspect}, #{cert_passwd.inspect}, #{cert_file.inspect}>"
        end

        def self.perform(*args)
          app_name = args[0]
          @aps_retry = args[1] || false
          begin
            Resque.enqueue_aps_application(app_name) if @aps_retry
            count, duration, ex = Resque::Plugins::Aps::Application.perform_no_fail(app_name)
            logger.info("Sent #{count} #{app_name} notifications in batch over #{duration} sec.") if logger
            Resque.dequeue_aps_application(app_name) if @aps_retry
            raise ex if ex
          rescue
            Resque.dequeue_aps_application(app_name) if @aps_retry
            raise $!
          end
        end

        def self.perform_clear(app_name)
          while true
            count, duration, ex = Resque::Plugins::Aps::Application.perform_no_fail(app_name, false, true)
            p "Sent #{count} #{app_name} notifications in batch over #{duration} sec. Returned #{ex.inspect}"
            break if ex.nil?
          end
        end

        def self.perform_no_fail(app_name, requeue = true, read_response = false)
          count = 0
          start = Time.now
          excep = nil
          duration = Benchmark.realtime do
            Resque.aps_application(app_name).socket do |socket, app|
              n_old = nil
              while true
                n = Resque.dequeue_aps(app_name)
                if n.nil?
                  if @aps_retry && app.aps_nil_notification_retry?(count, start)
                    next
                  else
                    break
                  end
                end

                app.before_aps_write n
                begin
                  n.batch_id = count + 1
                  n.expiry   = Time.now.utc.to_i + 3600
                  socket.write(n.formatted)
                  app.after_aps_write n
                  count += 1
                  if read_response
                    resp = socket.read
                    if resp && resp != ""
                      # logger.error "Failure response: #{resp.inspect}" if logger
                      logger.error "Failure response: #{resp.bytes.to_a.map{|i| i.to_s(16)}.join}" if logger
                      break
                    end
                  end
                rescue
                  # logger.error Application.application_exception($!, app_name) if logger
                  app.failed_aps_write n, $!, n_old
                  logger.error "#{$!}: Sent #{count} notifications before failure." if logger
                  Resque.enqueue_aps(app_name, n) if requeue
                  excep = $!
                  break
                end
                n_old = n
              end
            end
          end
          return count, duration, excep
        end
    
        def self.verify_ssl_certificate(preverify_ok, ssl_context)
          if preverify_ok != true || ssl_context.error != 0
            err_msg = "SSL Verification failed -- Preverify: #{preverify_ok}, Error: #{ssl_context.error_string} (#{ssl_context.error})"
            raise OpenSSL::SSL::SSLError.new(err_msg)
          end
          true
        end

        #
        # Create the TCP and SSL sockets for sending the notification
        #
        def self.create_sockets(cert, passphrase, host, port)
          ctx = OpenSSL::SSL::SSLContext.new
          ctx.key = OpenSSL::PKey::RSA.new(cert, passphrase)
          ctx.cert = OpenSSL::X509::Certificate.new(cert)

          if @@CAFile && File.exists?(@@CAFile)
            ctx.ca_file = @@CAFile
          end
          if defined?(ROOT_CA) && ROOT_CA && File.directory?(ROOT_CA)
            ctx.ca_path = ROOT_CA
          end
          ctx.verify_callback = proc do |preverify_ok, ssl_context|
            Resque::Plugins::Aps::Application.verify_ssl_certificate(preverify_ok, ssl_context)
          end

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

        def self.application_exception(exception, name)
          exc = Exception.new("#{exception} (#{name})")
          exc.set_backtrace(exception.backtrace)
          return exc
        end

        def initialize(attributes)
          attributes.each do |k, v|
            respond_to?(:"#{k}=") ? send(:"#{k}=", v) : raise(Resque::Plugins::Aps::UnknownAttributeError, "unknown attribute: #{k}")
          end
        end

        def socket(cert = nil, certp = nil, host = nil, port = nil, &block)
          logger.debug("resque-aps: ssl_socket(#{name})") if logger
          exc = nil

          begin
            socket, ssl_socket = Application.create_sockets(cert || File.read(cert_file),
                                                            certp || cert_passwd,
                                                            host || Resque.aps_gateway_host,
                                                            port || Resque.aps_gateway_port)
          rescue
            raise Application.application_exception($!, name)
          end

          begin
            ssl_socket.connect
            yield ssl_socket, self if block_given?
          rescue
            exc = Application.application_exception($!, name)
            if $!.message =~ /^SSL_connect .* certificate (expired|revoked)/ || $!.message =~ /^SSL Verification failed/
              notify_aps_admin exc
            end
            raise exc
          ensure
            Application.close_sockets(socket, ssl_socket)
          end

          exc
        end

        def to_hash
          {'name' => name, 'cert_file' => cert_file, 'cert_passwd' => cert_passwd}
        end

        def to_json
          to_hash.to_json
        end

        def before_aps_write(notification)
          logger.debug("ResqueAps[before_write]: #{notification}") if logger
        end

        def after_aps_write(notification)
          logger.debug("ResqueAps[after_write]: #{notification}") if logger
        end

        def failed_aps_write(notification, exception, previous_notification = nil)
          logger.error("ResqueAps[write_failed]: #{exception} (#{notification}): #{exception.backtrace.join("\n")}") if logger
        end

        def notify_aps_admin(exception)
        end

        def aps_nil_notification_retry?(sent_count, start_time)
          false
        end

        def before_aps_read
          logger.debug("ResqueAps[before_read]:") if logger
        end
    
        def after_aps_read(feedback)
          logger.debug("ResqueAps[after_read]: #{feedback.to_s}") if logger
        end
    
        def aps_read_error(exception)
          logger.error("ResqueAps[read_error]: #{exception} (#{name}): #{exception.backtrace.join("\n")}") if logger
        end

        def aps_read_failed
          logger.error("ResqueAps[read_failed]: Bad data on the socket (#{name})") if logger
        end

      end
    end
  end
end