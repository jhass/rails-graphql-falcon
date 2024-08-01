#!/usr/bin/env -S falcon host

load :rack

hostname = File.basename(__dir__)
port = ENV["PORT"] || 3000

rack hostname do
  count ENV.fetch("WEB_CONCURRENCY", 1).to_i
  append preload "preload.rb"
  endpoint Async::HTTP::Endpoint.parse("http://0.0.0.0:#{port}")
end
