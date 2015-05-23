#!/usr/bin/env ruby

require "rack"
require "rack/handler/puma"
require "rack/builder"

class FakeService
  attr_accessor :state

  def initialize
    p "here"
    @random = Random.new
    @state = :up
  end

  def call(env)
    case @state
    when :up
      sleep @random.rand(0.050)
      [200, { "Content-Type" => "text/html" }, ["up"]]
    when :die
      sleep @random.rand(1.000)
      [500, { "Content-Type" => "text/html" }, ["down"]]
    when :slowdown
      sleep @random.rand(10.000)
      [200, { "Content-Type" => "text/html" }, ["slooow"]]
    else
      fail "what is that again?"
    end
  end
end

$service = FakeService.new

def set_state_action(state)
  lambda { |_| $service.state = state; [200, { "Content-Type" => "text/html" }, ["OK"]] }
end

app = Rack::Builder.new do
  map("/" ) { run $service }
  map("/die") { run set_state_action(:die) }
  map("/slowdown") { run set_state_action(:slowdown) }
  map("/up") { run set_state_action(:up) }
end

server = ::Rack::Handler::Puma
server.run app, Port: 8081
