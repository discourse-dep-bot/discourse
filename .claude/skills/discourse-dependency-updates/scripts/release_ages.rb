#!/usr/bin/env ruby
# frozen_string_literal: true

# Prints the latest release and the newest release old enough to adopt.
#
# Usage: release_ages.rb [--days N] gem:NAME[@VERSION] npm:NAME[@VERSION] ...
#
# With @VERSION, also prints that version's age.

require "json"
require "net/http"
require "time"

days = 7
if (i = ARGV.index("--days"))
  days = Integer(ARGV[i + 1])
  ARGV.slice!(i, 2)
end
abort "Usage: release_ages.rb [--days N] gem:NAME[@VERSION] npm:NAME[@VERSION] ..." if ARGV.empty?

cutoff = Time.now - (days * 86_400)

def fetch_json(url, headers = {})
  uri = URI(url)
  request = Net::HTTP::Get.new(uri)
  headers.each { |k, v| request[k] = v }
  response = Net::HTTP.start(uri.host, uri.port, use_ssl: true) { |http| http.request(request) }
  raise "#{url}: HTTP #{response.code}" unless response.is_a?(Net::HTTPSuccess)
  JSON.parse(response.body)
end

# Returns [[version, released_at], ...] for stable releases, oldest first.
def releases(ecosystem, name)
  case ecosystem
  when "gem"
    fetch_json("https://rubygems.org/api/v1/versions/#{name}.json")
      .reject { |v| v["prerelease"] }
      .map { |v| [v["number"], Time.parse(v["created_at"])] }
      .uniq(&:first)
  when "npm"
    url = "https://registry.npmjs.org/#{name.sub("/", "%2F")}"
    times = fetch_json(url, "Accept" => "application/json")["time"]
    times
      .except("created", "modified")
      .reject { |v, _| v.include?("-") }
      .map { |v, t| [v, Time.parse(t)] }
  else
    raise "Unknown ecosystem #{ecosystem.inspect}; use gem: or npm:"
  end.sort_by(&:last)
end

def age(time) = format("%.1fd", (Time.now - time) / 86_400)

ARGV.each do |arg|
  ecosystem, spec = arg.split(":", 2)
  name, version = spec.match(/\A(@?[^@]+)(?:@(.+))?\z/).captures
  list = releases(ecosystem, name)
  latest = list.last
  eligible = list.reverse.find { |_, t| t <= cutoff }

  line = "#{arg.ljust(40)} latest #{latest[0]} (#{age(latest[1])})"
  line +=
    eligible ? "  newest >= #{days}d #{eligible[0]} (#{age(eligible[1])})" : "  nothing >= #{days}d"
  if version
    found = list.find { |v, _| v == version }
    line += found ? "  #{version} is #{age(found[1])} old" : "  #{version} not found"
  end
  puts line
rescue => e
  puts "#{arg}: #{e.message}"
end
