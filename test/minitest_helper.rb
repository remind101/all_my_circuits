$LOAD_PATH.unshift File.expand_path('../../lib', __FILE__)
require 'all_my_circuits'

require 'minitest/autorun'

class AllMyCircuitsTC < Minitest::Test
  def self.test(name, &block)
    block ||= proc { skip }
    define_method("test_#{name}", &block)
  end

  def self.xtest(name, &block)
    test(name)
  end
end
