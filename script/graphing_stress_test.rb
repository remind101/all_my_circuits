#!/usr/bin/env ruby

$:.unshift File.expand_path("../../lib", __FILE__)
require "all_my_circuits"
require_relative "./graphing_server"
require "thread"
require "net/http"
require "uri"
require "timeout"
# require_relative "./../../cb2/lib/cb2"
require "securerandom"

WORKERS = Integer(ENV["WORKERS"]) rescue 25

def setup
  @responses_queue = Queue.new
  @breaker = AllMyCircuits::Breaker.new(
    name: "test service circuit breaker",
    strategy: {
      name: :percentage_over_window,
      requests_window: 20,
      failure_rate_percent_threshold: 25,
      sleep_seconds: 10
    }
  )
  # @breaker = CB2::Breaker.new(
  #   strategy: :percentage,
  #   duration: 5,
  #   reenable_after: 10,
  #   threshold: 50
  # )
  @datapoints_queue = Queue.new
  @commands_queue = Queue.new
end

def run
  setup
  workers = run_workers
  graphing_server = run_graphing_server

  loop do
    response = @responses_queue.pop
    @datapoints_queue.push(response)
  end

  workers.each(&:kill)
  graphing_server.kill
end

def run_workers
  WORKERS.times.map do
    Thread.new(@responses_queue, @breaker) do |responses, breaker|
      loop do
        begin
          t1 = Time.now
          @breaker.run do
            Timeout.timeout(2) do
              response = Net::HTTP.get_response(URI("http://localhost:8081"))
              response.value
              log "success"
              responses.push(status: :succeeded, started: t1.to_f, finished: Time.now.to_f)
            end
          end
        rescue AllMyCircuits::BreakerOpen, CB2::BreakerOpen
          log "breaker open"
          responses.push(status: :skipped, started: t1.to_f, finished: Time.now.to_f)
        rescue
          log "failure #{$!.inspect}: #{$!.backtrace.first(2).join(", ")}"
          responses.push(status: :failed, started: t1.to_f, finished: Time.now.to_f)
        end
      end
    end
  end
end

def run_graphing_server
  Thread.new(@datapoints_queue) do |datapoints_queue|
    GraphingServer.start(datapoints_queue)
  end
end

def log(msg)
  @mtx ||= Mutex.new
  timestamp = "%10.6f" % Time.now.to_f
  @mtx.synchronize { puts "[#{Thread.current.object_id}] #{timestamp}: #{msg}" if ENV["DEBUG"] }
end

run
