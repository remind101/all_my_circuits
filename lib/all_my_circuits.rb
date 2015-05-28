require "all_my_circuits/version"
require "logger"

module AllMyCircuits
  require "all_my_circuits/exceptions"

  autoload :Breaker,     "all_my_circuits/breaker"
  autoload :Clock,       "all_my_circuits/clock"
  autoload :Logging,     "all_my_circuits/logging"
  autoload :Notifiers,   "all_my_circuits/notifiers"
  autoload :NullBreaker, "all_my_circuits/null_breaker"
  autoload :Strategies,  "all_my_circuits/strategies"
  autoload :VERSION,     "all_my_circuits/version"

  class << self
    attr_accessor :logger
  end
  @logger = Logger.new(STDERR)
  @logger.level = Integer(ENV["ALL_MY_CIRCUITS_LOG_LEVEL"]) rescue Logger::ERROR
end
