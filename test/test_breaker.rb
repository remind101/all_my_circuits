require "minitest_helper"

class TestBreaker < AllMyCircuitsTC
  def setup
    @clock = FakeClock.new
  end

  def make_breaker(strategy: {}, notifier: {}, watch_errors: [SimulatedFailure])
    AllMyCircuits::Breaker.new(
      name: "my service",
      watch_errors: watch_errors,
      sleep_seconds: 5,
      clock: @clock,
      strategy: FakeStrategy.new({ should_open: proc { false } }.merge(strategy)),
      notifier: FakeNotifier.new("my service", notifier)
    )
  end

  test "lets request through when closed" do
    breaker = make_breaker(strategy: { should_open: proc { false } })
    result = breaker.run do
      :such_result
    end
    assert_equal :such_result, result
  end

  test "rejects request and raises AllMyCircuits::BreakerOpen if open" do
    breaker = make_breaker(strategy: { should_open: proc { true } })
    breaker.run { raise SimulatedFailure, "uh-oh" } rescue nil # trip it open
    e = assert_raises AllMyCircuits::BreakerOpen do
      breaker.run { :whatevs }
    end
    assert_includes "my service", e.message
  end

  test "re-raises watched errors" do
    breaker = make_breaker(watch_errors: [SimulatedFailure])
    assert_raises SimulatedFailure do
      breaker.run { raise SimulatedFailure, "uh-oh" }
    end
  end

  test "re-raises unwatched errors" do
    breaker = make_breaker(watch_errors: [])
    assert_raises RuntimeError do
      breaker.run { raise RuntimeError, "uh-oh" }
    end
  end

  test "asks strategy whether should be opened on error" do
    asked = false
    breaker = make_breaker(strategy: { should_open: proc { asked = true; true } })
    breaker.run { raise SimulatedFailure, "uh-oh" } rescue nil # trip it open
    assert asked, "expecte circuit breaker to ask strategy whether it should be opened"
  end

  test "notifies strategy on error" do
    notified = false
    breaker = make_breaker(strategy: { error: proc { notified = true } })
    breaker.run { raise SimulatedFailure, "uh-oh" } rescue nil
    assert notified, "expected breaker to notify the strategy on error"
  end

  test "does not notify strategy about unwatched errors" do
    notified = false
    breaker = make_breaker(strategy: { error: proc { notified = true } }, watch_errors: [SimulatedFailure])
    breaker.run { raise RuntimeError, "uh-oh" } rescue nil
    refute notified, "expected breaker not to notify strategy about unwatched error"
  end

  test "notifies strategy on success" do
    notified = false
    breaker = make_breaker(strategy: { success: proc { notified = true } })
    breaker.run { "success" }
    assert notified, "expected breaker to notify the strategy on success"
  end

  test "notifies strategy on opened" do
    notified = false
    breaker = make_breaker(strategy: { should_open: proc { true }, opened: proc { notified = true } })
    breaker.run { raise SimulatedFailure, "uh-oh" } rescue nil # trip it open
    assert notified, "expected circuit breaker to notify the strategy when opened"
  end

  test "notifies strategy on closed" do
    notified = false
    breaker = make_breaker(strategy: { should_open: proc { true }, closed: proc { notified = true } })
    breaker.run { raise SimulatedFailure, "uh-oh" } rescue nil # trip it open
    @clock.advance(5)
    breaker.run { "wild success" }
    assert notified, "expected circuit breaker to notify the strategy when closed"
  end

  test "on success closes the circuit" do
    breaker = make_breaker(strategy: { should_open: proc { true } })
    breaker.run { raise SimulatedFailure, "uh-oh" } rescue nil # trip it open
    @clock.advance(5)
    breaker.run { "wild success" }
    breaker.run { "more wild success" } # not open
  end

  test "when opened, notifies notifier" do
    opened_breaker = nil
    breaker = make_breaker(
      strategy: { should_open: proc { true } },
      notifier: { opened: proc { |breaker_name| opened_breaker = breaker_name } }
    )
    breaker.run { raise SimulatedFailure, "uh-oh" } rescue nil # trip it open
    assert_equal "my service", opened_breaker
  end

  test "when closed, notifies notifier" do
    closed_breaker = nil
    breaker = make_breaker(
      strategy: { should_open: proc { true } },
      notifier: { closed: proc { |breaker_name| closed_breaker = breaker_name } }
    )
    breaker.run { raise SimulatedFailure, "uh-oh" } rescue nil # trip it open
    @clock.advance(5)
    breaker.run { "wild success" }
    assert_equal "my service", closed_breaker
  end
end
