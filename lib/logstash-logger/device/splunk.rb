require 'poseidon'
require 'net/http'

module LogStashLogger
  module Device
    class Client
      def initialize(uri:,token:)
        @uri = uri
        @client = Net::HTTP.new(uri.host,uri.port)
        @token =  token
      end

      def send_message(message)
        req = Net::HTTP::Post.new(@uri.request_uri,{
          'Content-Type' => 'application/x-www-form-urlencoded',
          'Authorization' =>  "Splunk #{@token}"
        })
        req.body = message
        response = @client.request(request)
      end

      def close
        true
      end

    end
    
    class Splunk < Connectable

      DEFAULT_HOST = 'localhost'
      DEFAULT_PORT = 8080
      DEFAULT_PATH = ''
      DEFAULT_PROTOCOL = 'https'
      DEFAULT_BACKOFF = 1
      DEFAULT_AUTH =  ''

      attr_accessor :backoff

      def initialize(opts)
        super
        host = opts[:host] || DEFAULT_HOST
        port = opts[:port] || DEFAULT_PORT
        protocol = opts[:protocol] || DEFAULT_PROTOCOL
        path = opts[:path] || DEFAULT_PATH
        token = opts[:token] || DEFAULT_AUTH
        uri = URI.parse(protocol+"://"+host+":"+port+"/"+path)
        @client = Client.new(uri:uri,token:token)
      end

      def connect
        @io = @client
      end

      def with_connection
        connect
        yield
      rescue ::Poseidon::Errors::ChecksumError, Poseidon::Errors::UnableToFetchMetadata => e
        log_error(e)
        log_warning("reconnect/retry")
        sleep backoff if backoff
        reconnect
        retry
      rescue => e
        log_error(e)
        log_warning("giving up")
        close(flush: false)
      end

      def write_batch(messages, topic = nil)
        topic ||= @topic
        with_connection do
          @io.send_message(messages.join)
        end
      end

      def write_one(message, topic = nil)
        write_batch([message], topic)
      end
    end
  end
end
