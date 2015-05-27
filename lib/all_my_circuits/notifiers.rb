module AllMyCircuits

  module Notifiers
    autoload :AbstractNotifier, "all_my_circuits/notifiers/abstract_notifier"
    autoload :NullNotifier,     "all_my_circuits/notifiers/null_notifier"
  end

end
