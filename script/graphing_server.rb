require "rack"
require "rack/handler/puma"
require "json"

class Stream
  def initialize(data_queue)
    @data_queue = data_queue
  end

  def each
    loop do
      data_batch = []
      frame_start = Time.now
      while Time.now.to_i == frame_start.to_i
        data_batch << @data_queue.pop
      end
      counts = { succeeded: 0, failed: 0, skipped: 0, currentTime: frame_start.to_f * 1000 }.
        merge(Hash[data_batch.group_by { |p| p[:status] }.map { |status, points| [status, points.length] }])
      serialized = "data: %s\n\n" % counts.to_json
      yield serialized
    end
  end
end

class GraphingServer
  def self.start(data_queue)
    server = ::Rack::Handler::Puma
    server.run Rack::Chunked.new(new(Stream.new(data_queue)))
  rescue => e
    warn "graphing server wtf #{e.inspect} #{e.backtrace}"
    raise
  end

  PAGE = <<-PAGE
    <!DOCTYPE html>
    <html>
      <head>
        <title>AlLMyCircuits Stress Test Graph</title>
        <script src="//cdnjs.cloudflare.com/ajax/libs/jquery/2.1.4/jquery.min.js" type="text/javascript"></script>
        <script src="https://rawgit.com/joewalnes/smoothie/master/smoothie.js" type="text/javascript"></script>
        <style type="text/css">
          html{
            height: 100%;
          }
          body {
            min-height: 100%;
          }
        </style>
      </head>
      <body>
        <canvas id="workersSuccess" width="1000" height="300"></canvas>
        <canvas id="workersFailure" width="1000" height="300"></canvas>
        <canvas id="workersSkip" width="1000" height="300"></canvas>
        <script type="text/javascript">
          var workersSuccessChart = new SmoothieChart({ interpolation: 'step', minValue: 0, maxValueScale: 1.2 });
          workersSuccessChart.streamTo(document.getElementById("workersSuccess"), 1000);
          var succeededCount = new TimeSeries();
          workersSuccessChart.addTimeSeries(succeededCount, { strokeStyle: "rgb(0, 255, 0)" });

          var workersFailureChart = new SmoothieChart({ interpolation: 'step', minValue: 0, maxValueScale: 1.2 });
          workersFailureChart.streamTo(document.getElementById("workersFailure"), 1000);
          var failedCount = new TimeSeries();
          workersFailureChart.addTimeSeries(failedCount, { strokeStyle: "rgb(255, 0, 0)" });

          var workersSkipChart = new SmoothieChart({ interpolation: 'step', minValue: 0, maxValueScale: 1.2 });
          workersSkipChart.streamTo(document.getElementById("workersSkip"), 1000);
          var skippedCount = new TimeSeries();
          workersSkipChart.addTimeSeries(skippedCount, { strokeStyle: "rgb(255, 255, 255)" });

          var source = new EventSource("/data");
          source.onmessage = function(event) {
            var points = JSON.parse(event.data);
            var currentTime = points.currentTime;
            succeededCount.append(currentTime, points.succeeded);
            failedCount.append(currentTime, points.failed);
            skippedCount.append(currentTime, points.skipped);
          };
        </script>
      </body>
    </html>
  PAGE

  def initialize(stream)
    @stream = stream
  end

  def call(env)
    req = Rack::Request.new(env)
    case req.path
    when "/"
      [200, { "Content-Type" => "text/html" }, [PAGE]]
    when "/data"
      [200, { "Content-Type" => "text/event-stream", "Connection" => "keepalive", "Cache-Control" => "no-cache, no-store" }, @stream]
    else
      [404, { "Content-Type" => "text/html" }, []]
    end
  end
end
