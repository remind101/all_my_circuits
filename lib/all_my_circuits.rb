require "all_my_circuits/version"

module AllMyCircuits
  require "all_my_circuits/exceptions"

  autoload :Breaker,    "all_my_circuits/breaker"
  autoload :Strategies, "all_my_circuits/strategies"
  autoload :Clock,      "all_my_circuits/clock"
  autoload :VERSION,    "all_my_circuits/version"
end
