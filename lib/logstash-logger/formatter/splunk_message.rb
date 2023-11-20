module LogStashLogger
  module Formatter
    class SplunkMessage < Base
      # customizer = ->(event){
      #   event["source"] ="my-cool-app"
      #   event["source_type"] ="web-app"
      #   event["index"] ="my-app-index"
      #   event["app_version"] =1.0
      # }
       #usage:LogStashLogger.new(customize_event: customizer)

      def initialize(customize_event:nil)
        super(customize_event:customize_event)
      end
      
      def format_event(event)
          {
            time: event.remove('@timestamp'),
            host: event.remove('host'),
            source: event.remove('source'),
            sourcetype: event.remove('source_type'),
            index:  event.remove('index'),
            event: {
              message: event.remove('message'),
              severity: event.remove('severity'),
            },
          fields: {
            app_version: event.remove('app_version'),
          }
          }.to_json
      end
    end
  end
end
