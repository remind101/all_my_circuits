require "minitest_helper"
require "thread"

class TestAllMyCircuitsAcrossMultipleThreads < AllMyCircuitsTC
  WORKERS = Integer(ENV["CONCURRENCY_TEST_WORKERS"]) rescue 25
  TEST_TIMES = Integer(ENV["CONCURRENCY_TEST_TIMES"]) rescue 1
  RESPONSE_TIME_SEC = 0.05

  def setup
    super
    @requests_queue = Queue.new
    @responses_queue = Queue.new
    @breaker = AllMyCircuits::Breaker.new(
      name: "test service circuit breaker",
      sleep_seconds: 2,
      strategy: {
        name: :number_over_window,
        requests_window: 10,
        failures_threshold: 10
      }
    )
  end

  Request = Struct.new(:action, :duration)

  test "works properly in concurrent environment" do
    workers = run_workers

    TEST_TIMES.times do
      log "== normal mode of operation =="

      n = 50
      send_n_requests(n, :succeed)
      assert_equal n, get_n_responses(n).count { |r| r == :succeeded }, "expected #{n} requests to succeed"

      log "== failure mode of operation =="
      n = 10
      send_n_requests(n, :fail)
      assert_equal n, get_n_responses(n).count { |r| r == :failed }, "expected #{n} requests to fail"

      log "== circuit is open =="
      n = 20
      send_n_requests(n, :succeed)
      assert_equal n, get_n_responses(n).count { |r| r == :skipped }, "expected #{n} requests to be skipped by circuit breaker"

      sleep 2 # wait till circuit surely half-closes

      log "== resume normal operation =="
      send_n_requests(1, :succeed)
      assert_equal 1, get_n_responses(1).count { |r| r == :succeeded }, "expected successful request after circuit went half-open"

      send_n_requests(25, :succeed)
      send_n_requests(5, :fail)
      send_n_requests(70, :succeed)
      responses = get_n_responses(100)
      assert_in_delta 0, responses.count { |r| r == :skipped }, WORKERS, "expected no more requests to be skipped than there are workers"
      assert 5 >= responses.count { |r| r == :failed }, "expected up to 5 requests to fail (or be open-circuited)"
      assert_in_delta 95, responses.count { |r| r == :succeeded }, WORKERS, "expected 95-WORKERS to 95 requests to succeed"

      printf "+"
    end
    workers.each(&:kill)
  end

  def send_n_requests(n, action)
    n.times { @requests_queue.push(Request.new(action, RESPONSE_TIME_SEC)) }
  end

  def get_n_responses(n)
    n.times.map { @responses_queue.pop }
  end

  def run_workers
    WORKERS.times.map do
      Thread.new(@requests_queue, @responses_queue, @breaker) do |requests, responses, breaker|
        random = Random.new
        loop do
          request = requests.pop
          begin
            @breaker.run do
              raise "service unavailable" if request.action == :fail
              log "success"
              responses.push :succeeded
            end
          rescue AllMyCircuits::BreakerOpen
            log "breaker open"
            responses.push :skipped
          rescue
            log "failure #{$!.inspect}: #{$!.backtrace.first(2).join(", ")}"
            responses.push :failed
          end
          sleep random.rand(request.duration)
        end
      end
    end
  end

  def log(msg)
    @mtx ||= Mutex.new
    timestamp = "%10.6f" % Time.now.to_f
    @mtx.synchronize { puts "[#{Thread.current.object_id}] #{timestamp}: #{msg}" if ENV["DEBUG"] }
  end
end
