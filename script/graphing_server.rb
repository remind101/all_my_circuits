require "rack"
require "rack/handler/puma"
require "json"

class Stream
  def initialize(data_queue)
    @data_queue = data_queue
  end

  def each
    batch_proto = { succeeded: 0, failed: 0, skipped: 0 }.freeze
    next_batch = batch_proto.dup
    loop do
      data_batch = next_batch
      next_batch = batch_proto.dup
      frame_end = Time.now + 1
      begin
        while r = @data_queue.pop(true)
          if r[:finished] <= frame_end
            data_batch[r[:status]] += 1
          else
            next_batch[r[:status]] += 1
            break
          end
        end
      rescue ThreadError # queue exhausted
        sleep 0.0001
        retry
      end
      data_batch[:currentTime] = frame_end.to_f * 1000
      serialized = "data: %s\n\n" % data_batch.to_json
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
        <title>AllMyCircuits Stress Test Graph</title>
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
          var chartHeight = window.innerHeight / 3 - 20;
          var chartWidth = window.innerWidth - 20;

          var charts = {
            succeeded: {
              elementId: "workersSuccess",
              color: "rgb(0, 255, 0)"
            },
            failed: {
              elementId: "workersFailure",
              color: "rgb(255, 0, 0)"
            },
            skipped: {
              elementId: "workersSkip",
              color: "rgb(255, 255, 255)"
            }
          };

          for (var chart in charts) {
            var chartConfig = charts[chart];
            var el = document.getElementById(chartConfig.elementId);
            el.height = chartHeight;
            el.width = chartWidth;

            var chart = new SmoothieChart({ interpolation: 'step', minValue: 0, maxValueScale: 1.2 });
            chart.streamTo(el, 1000);

            chartConfig.series = new TimeSeries();
            chart.addTimeSeries(chartConfig.series, { strokeStyle: chartConfig.color });
          }

          var source = new EventSource("/data");
          source.onmessage = function(event) {
            var points = JSON.parse(event.data);
            var currentTime = points.currentTime;
            charts.succeeded.series.append(currentTime, points.succeeded);
            charts.failed.series.append(currentTime, points.failed);
            charts.skipped.series.append(currentTime, points.skipped);
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
