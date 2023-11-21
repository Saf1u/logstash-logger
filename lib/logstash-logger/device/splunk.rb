require 'poseidon'
require 'net/http'


module LogStashLogger
  module Device

    class ClientError< StandardError
    end
    class SplunkError< StandardError
    end

    class Retry
      def initialize(max_retries:1)
        @max_retries = max_retries
        @current_retry_count = 0
      end
      def can_retry?
        return @current_retry_count < @max_retries_count
      end
      def exponential_wait
        @current_retry_count+=1
        max_sleep = Float(2**@current_retry_count)
        sleep rand(0..max_sleep)
      end
      def reset_retries
        @current_retry_count = 0
      end
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
      DEFAULT_MAX_RETRY = 1
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
        @retry =  Retry.new(max_retries: opts[:max_retry] || DEFAULT_MAX_RETRY )
      end

      def connect
        @io = @client
      end

      def with_connection
        connect unless connected?
        yield
      rescue ClientError => e
        log_error(e)
        log_warning("reconnect/retry")
        unless can_retry?
          @retry.reset_retries
          raise "max retry reached without succesful communication with server, giving up"
        end
        @retry.exponential_wait
        reconnect
        retry
      rescue SplunkError => e
        log_error(e)
        log_warning("giving up")
        close(flush: false)
      rescue => e
        log_error(e)
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
