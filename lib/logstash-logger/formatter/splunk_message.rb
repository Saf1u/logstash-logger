module LogStashLogger
  module Formatter
    class SplunkMessage < Base
      def initialize(customize_event:nil)
        @source = "source"
        @source_type = "source_type" #"_json"
        @index = "index"
        @app_version = "version"
      end
      def format_event(event)
          {
            time: event.remove('@timestamp'),
            host: event.remove('host'),
            source: @source,
            sourcetype: @source_type,
            index: @index,
            event: {
              message: event.remove('message'),
              severity: event.remove('severity'),
            },
          fields: {
            app_version: @app_version,
          }
          }.to_json
      end
    end
  end
end
