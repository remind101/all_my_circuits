require "minitest_helper"

class TestWindow < AllMyCircuitsTC
  def setup
    super
    @window = AllMyCircuits::Strategies::AbstractWindowStrategy::Window.new(4)
  end

  test "#<< adds events to the window" do
    @window << :foo << :bar
    assert_equal 1, @window.count(:foo)
    assert_equal 1, @window.count(:bar)
  end

  test "#<< trims the window" do
    @window << :reject << :keep << :keep << :keep
    @window << :keep
    assert_equal 4, @window.count(:keep)
    assert_equal 0, @window.count(:reject)
  end

  test "#count(event) returns number of events in the window" do
    @window << :foo << :bar << :foo
    assert_equal 2, @window.count(:foo)
    assert_equal 1, @window.count(:bar)
  end

  test "#count returns overall number of events in the window" do
    @window << :foo << :bar
    assert_equal 2, @window.count
  end

  test "#full? returns true if there is enough events in the window" do
    @window << :a << :b << :c << :d
    assert @window.full?, "expected window with 4 events to be full"
  end

  test "#full? returns false if there is not enough events in the window" do
    @window << :a << :b
    refute @window.full?, "expected window with 2 events not to be full"
  end

  test "#reset resets the window" do
    @window << :a << :b
    @window.reset!
    assert_equal 0, @window.count
  end
end

