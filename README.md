# AllMyCircuits

[![Circle CI](https://circleci.com/gh/remind101/all_my_circuits.svg?style=svg&circle-token=3c0f7294a61e095f789f369f96bdd266ddd80258)](https://circleci.com/gh/remind101/all_my_circuits)

![funny image goes here](https://raw.githubusercontent.com/remind101/all_my_circuits/master/all_my_circuits.jpg?token=AAc0YcX8xOhT0o4_Ko-IxKEEQk2PTUJYks5VaR0ywA%3D%3D)

AllMyCircuits is intended to be a threadsafe-ish circuit breaker implementation for Ruby.
See [Martin Fowler's article on the Circuit Breaker pattern for more info](http://martinfowler.com/bliki/CircuitBreaker.html).

# Usage

    class MyService
      include Singleton

      def initialize
        @circuit_breaker = AllMyCircuits::Breaker.new(
          name: "my_service",
          watch_errors: [Timeout::Error],               # defaults to AllMyCircuits::Breaker.net_errors,
                                                        #   which includes typical net/http and socket errors
          sleep_seconds: 10,                            # leave circuit open for 10 seconds, than try to call the service again
          strategy: AllMyCircuits::Strategies::PercentageOverWindowStrategy.new(
            requests_window: 100,                       # number of requests to calculate the average failure rate for
            failure_rate_percent_threshold: 25          # open circuit if 25% or more requests within 100-request window fail
                                                        #   must trip open again if the first request fails
          }
        )
      end

      def run
        begin
          @breaker.run do
            Timeout.timeout(1.0) { my_risky_call }
          end
        rescue AllMyCircuits::BreakerOpen => e
          # log me somewhere
        rescue
          # uh-oh, risky call failed once
        end
      end
    end

# Testing

So, what have we got:

  * Time-sensitive code: ...check
  * Concurrent code:     ...check

Dude, that's a real headache for someone who's not confortable enough with concurrent code.
I haven't figured any awesome way of automated testing in this case.
So, in the [script](https://github.com/remind101/all_my_circuits/tree/master/script) folder, there are:

  * [fake_service.rb](https://github.com/remind101/all_my_circuits/blob/master/script/fake_service.rb)
  * [graphing_stress_test.rb](https://github.com/remind101/all_my_circuits/blob/master/script/graphing_stress_test.rb)

## fake_service.rb

the Fake Service has 3 modes of operation: `up` (default), `die` and `slowdown`.

  * `up` (default) - http://localhost:8081/up - normal mode of operation, latency up to 50ms
  * `die` - http://localhost:8081/die - exceptions are raised left and right, slight delay in response
  * `slowdown` - http://localhost:8081/slowdown - successful responses with a significant delay.

## Graphing Stress Test

runs `WORKERS` number of workers which continuously hit http://localhost:8081. Graphs are served at http://localhost:8080.
This app allows to catch incorrect circuit breaker behavior visually.

# Logging

Logger can be configured by setting `AllMyCircuits.logger`.
Default log device is STDERR, and default level is ERROR (can be overridden with `ALL_MY_CIRCUITS_LOG_LEVEL` environment variable).

# TODO

  * global controls through redis?

