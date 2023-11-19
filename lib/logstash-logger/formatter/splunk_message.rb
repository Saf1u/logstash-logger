module LogStashLogger
  module Formatter
    class SplunkMessage < Base
      def initialize(source, source_type, index, version)
        super()
        @source = source
        @source_type = source_type
        @index = index
        @app_version = version
      end
      def format_event(event)
        event.tap do |event|
          body={
            time: event.remove('@timestamp'),
            host: event.remove('host'),
            source: @source,
            sourcetype: @source_type,
            index: @index,
            app_version: @app_version, #checl 
            event: {
              message: event.remove('message')
              severity: event.remove('severity')
            }
          },
        end
      end
    end
  end
end
