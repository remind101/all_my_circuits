module AllMyCircuits

  module Strategies
    autoload :AbstractWindowStrategy,   "all_my_circuits/strategies/abstract_window_strategy"
    autoload :PercentageWindowStrategy, "all_my_circuits/strategies/percentage_window_strategy"
    autoload :NumberWindowStrategy,     "all_my_circuits/strategies/number_window_strategy"
  end

end
