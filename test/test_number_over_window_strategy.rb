require "minitest_helper"

class TestNumberOverWindowStrategy < AllMyCircuitsTC
  def setup
    super
    @strategy = AllMyCircuits::Strategies::NumberOverWindowStrategy.new(
      requests_window: 4,
      failures_threshold: 3
    )
  end

  test "does not tell the circuit to open until window is full" do
    @strategy.error
    @strategy.error
    @strategy.error # 3 failures within 4-requests window, but window is not full yet.
    refute @strategy.should_open?, "expected strategy not to open the circuit until the window is full"
  end

  test "tells the circuit to open if failure threshold is reached" do
    @strategy.error
    @strategy.error
    @strategy.success
    @strategy.error
    assert @strategy.should_open?, "expected strategy to open the circuit upon reaching the threshold"
  end

  test "does not tell the circuit to open if failure threshold has not been reached" do
    @strategy.success
    @strategy.success
    @strategy.error
    @strategy.error
    refute @strategy.should_open?, "expected strategy not to open the circuit before reaching the threshold"
  end
end

