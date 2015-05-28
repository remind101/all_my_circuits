require "minitest_helper"

class TestNullBreaker < AllMyCircuitsTC
  test "aways allows requests when initialized to be closed" do
    breaker = make_breaker(closed: true)
    ran = false
    breaker.run { ran = true }
    assert ran, "expected null breaker that is closed to allow all requests"
  end

  test "aways rejects requests when initialized to be open" do
    breaker = make_breaker(closed: false)
    assert_raises AllMyCircuits::BreakerOpen do
      breaker.run {}
    end
  end

  test "has a name" do
    breaker = make_breaker(name: "that thing")
    assert_equal "that thing", breaker.name
  end

  test "can change state" do
    breaker = make_breaker(closed: true)
    breaker.run { "wild success" }

    breaker.closed = false
    assert_raises AllMyCircuits::BreakerOpen do
      breaker.run { "never happens" }
    end
  end

  def make_breaker(overrides = {})
    AllMyCircuits::NullBreaker.new({ name: "LOL SUCH NOOP", closed: true }.merge(overrides))
  end
end
