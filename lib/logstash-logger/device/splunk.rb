require 'poseidon'
require 'net/http'


module LogStashLogger
  module Device

    class ClientError< StandardError
    end
    class SplunkError< StandardError
    end
    class Client
      def initialize(uri:,token:,ssl_enabled:)
        @uri = uri
        @client = Net::HTTP.new(uri.host,uri.port)
        @client.use_ssl = ssl_enabled
        @token =  token
      end

      def send_message(message)
        req = Net::HTTP::Post.new(@uri.request_uri,{
          'Content-Type' => 'application/x-www-form-urlencoded',
          'Authorization' =>  "Splunk #{@token}"
        })
        req.body = message
        response = @client.request(req)
        process_response(response)
      end

      def process_response(response)
        raise ClientError.new("Error status code #{response.code}")  if response.code!='200'
        return if response.body.length ==0
        response_hash = JSON.parse(response.body).to_h
        #resuce this possible parse error should never happen though
        return unless response_hash.key?("code")
        return unless response_hash["code"].to_s != '0'
        raise SplunkError.new(response_hash["text"])
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
        uri = URI.parse(protocol+"://"+host+":"+port + path)
        ssl_enabled = protocol === DEFAULT_PROTOCOL ? true:false
        @client = Client.new(uri:uri,token:token,ssl_enabled:ssl_enabled)
      end

      def connect
        @io = @client
      end

      def with_connection
        connect
        yield
      rescue ClientError => e
        log_error(e)
        log_warning("reconnect/retry")
        sleep backoff if backoff
        reconnect
        retry
      rescue SplunkError => e
        log_error(e)
        log_warning("giving up")
        close(flush: false)
      end

      def write_batch(messages, topic = nil)
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
