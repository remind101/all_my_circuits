require "minitest_helper"

class TestBreaker < AllMyCircuitsTC
  def setup
    @clock = FakeClock.new
  end

  def make_breaker(strategy_overrides: {}, notifier_overrides: {})
    AllMyCircuits::Breaker.new(
      name: "my service",
      sleep_seconds: 5,
      clock: @clock,
      strategy: {
        name: :fake_strategy,
        should_open: proc { false }
      }.merge(strategy_overrides),
      notifier: {
        name: :fake_notifier
      }.merge(notifier_overrides)
    )
  end

  test "lets request through when closed" do
    breaker = make_breaker(strategy_overrides: { should_open: proc { false } })
    ran = false
    breaker.run do
      ran = true
    end
    assert ran, "expected request to run through circuit breaker"
  end

  test "rejects request and raises AllMyCircuits::BreakerOpen if open" do
    breaker = make_breaker(strategy_overrides: { should_open: proc { true } })
    breaker.run { raise "uh-oh" } rescue nil # trip it open
    assert_raises AllMyCircuits::BreakerOpen do
      breaker.run { :whatevs }
    end
  end

  test "asks strategy whether should be opened on error" do
    asked = false
    breaker = make_breaker(strategy_overrides: { should_open: proc { asked = true; true } })
    breaker.run { raise "uh-oh" } rescue nil # trip it open
    assert asked, "expecte circuit breaker to ask strategy whether it should be opened"
  end

  test "notifies strategy on error" do
    notified = false
    breaker = make_breaker(strategy_overrides: { error: proc { notified = true } })
    breaker.run { raise "uh-oh" } rescue nil
    assert notified, "expected breaker to notify the strategy on error"
  end

  test "notifies strategy on success" do
    notified = false
    breaker = make_breaker(strategy_overrides: { success: proc { notified = true } })
    breaker.run { "success" }
    assert notified, "expected breaker to notify the strategy on success"
  end

  test "notifies strategy on opened" do
    notified = false
    breaker = make_breaker(strategy_overrides: { should_open: proc { true }, opened: proc { notified = true } })
    breaker.run { raise "uh-oh" } rescue nil # trip it open
    assert notified, "expecte circuit breaker to notify the strategy when opened"
  end

  test "notifies strategy on closed" do
    notified = false
    breaker = make_breaker(strategy_overrides: { should_open: proc { true }, closed: proc { notified = true } })
    breaker.run { raise "uh-oh" } rescue nil # trip it open
    @clock.advance(5)
    breaker.run { "wild success" }
    assert notified, "expected circuit breaker to notify the strategy when closed"
  end

  test "on success closes the circuit" do
    breaker = make_breaker(strategy_overrides: { should_open: proc { true } })
    breaker.run { raise "uh-oh" } rescue nil # trip it open
    @clock.advance(5)
    breaker.run { "wild success" }
    breaker.run { "more wild success" } # not open
  end

  test "when opened, notifies notifier" do
    opened_breaker = nil
    breaker = make_breaker(
      strategy_overrides: { should_open: proc { true } },
      notifier_overrides: { opened: proc { |breaker_name| opened_breaker = breaker_name } }
    )
    breaker.run { raise "uh-oh" } rescue nil # trip it open
    assert_equal "my service", opened_breaker
  end

  test "when closed, notifies notifier" do
    closed_breaker = nil
    breaker = make_breaker(
      strategy_overrides: { should_open: proc { true } },
      notifier_overrides: { closed: proc { |breaker_name| closed_breaker = breaker_name } }
    )
    breaker.run { raise "uh-oh" } rescue nil # trip it open
    @clock.advance(5)
    breaker.run { "wild success" }
    assert_equal "my service", closed_breaker
  end
end
