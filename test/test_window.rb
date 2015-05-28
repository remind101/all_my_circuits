require "minitest_helper"

class TestWindow < AllMyCircuitsTC
  def setup
    super
    @window = AllMyCircuits::Strategies::AbstractWindowStrategy::Window.new(4)
  end

  test "requires size >= 1" do
    assert_raises ArgumentError do
      AllMyCircuits::Strategies::AbstractWindowStrategy::Window.new(0)
    end
  end

  test "#<< adds events to the window" do
    @window << :succeeded << :failed
    assert_equal 1, @window.count(:succeeded)
    assert_equal 1, @window.count(:failed)
  end

  test "#<< trims the window at the beginning" do
    @window << :failed << :succeeded << :failed << :succeeded
    @window << :succeeded
    assert_equal 3, @window.count(:succeeded)
    assert_equal 1, @window.count(:failed)
  end

  test "#<< does not make counts go negative" do
    @window << :succeeded << :succeeded << :succeeded << :succeeded
    @window << :succeeded
    assert_equal 4, @window.count(:succeeded)
    assert_equal 0, @window.count(:failed)
  end

  test "#<< evicts correct event when full" do
    @window << :failed << :succeeded << :succeeded << :failed
    @window << :failed
    assert_equal 2, @window.count(:succeeded)
    assert_equal 2, @window.count(:failed)
  end

  test "#count(event) returns number of events in the window" do
    @window << :succeeded << :failed << :succeeded
    assert_equal 2, @window.count(:succeeded)
    assert_equal 1, @window.count(:failed)
  end

  test "#count returns overall number of events in the window" do
    @window << :succeeded << :failed
    assert_equal 2, @window.count
  end

  test "#full? returns true if there is enough events in the window" do
    @window << :succeeded << :succeeded << :failed << :failed
    assert @window.full?, "expected window with 4 events to be full"
  end

  test "#full? returns false if there is not enough events in the window" do
    @window << :succeeded << :succeeded
    refute @window.full?, "expected window with 2 events not to be full"
  end

  test "#reset resets the window" do
    @window << :succeeded << :failed
    @window.reset!
    assert_equal 0, @window.count
  end
end
