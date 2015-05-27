require "all_my_circuits/version"

module AllMyCircuits
  require "all_my_circuits/exceptions"

  autoload :Breaker,    "all_my_circuits/breaker"
  autoload :Clock,      "all_my_circuits/clock"
  autoload :Notifiers,  "all_my_circuits/notifiers"
  autoload :Strategies, "all_my_circuits/strategies"
  autoload :VERSION,    "all_my_circuits/version"
end
