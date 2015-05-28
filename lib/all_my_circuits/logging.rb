module AllMyCircuits

  module Logging
    def debug(message, breaker_name, request_number = nil)
      AllMyCircuits.logger.debug(format_line(message, breaker_name, request_number))
    end

    def info(message, breaker_name, request_number = nil)
      AllMyCircuits.logger.info(format_line(message, breaker_name, request_number))
    end

    private

    def format_line(message, breaker_name, request_number)
      if request_number.nil?
        "[%s] %s" % [breaker_name, message]
      else
        "[%s] req. #%s: %s" % [breaker_name, request_number, message]
      end
    end
  end

end
