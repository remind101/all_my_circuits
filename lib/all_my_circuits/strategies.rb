module AllMyCircuits

  module Strategies
    autoload :AbstractStrategy,             "all_my_circuits/strategies/abstract_strategy"
    autoload :AbstractWindowStrategy,       "all_my_circuits/strategies/abstract_window_strategy"
    autoload :PercentageOverWindowStrategy, "all_my_circuits/strategies/percentage_over_window_strategy"
    autoload :NumberOverWindowStrategy,     "all_my_circuits/strategies/number_over_window_strategy"
  end

end
