#!/usr/bin/env ruby

require "net/https"
require "json"

gh_token     = ENV["GH_TOKEN"]
gh_user      = ARGV.fetch(0)
gh_repo      = ARGV.fetch(1)
release_name = ARGV.fetch(2)
#release_desc = ARGV[3]

uri = URI("https://api.github.com")
http = Net::HTTP.new(uri.host, uri.port)
http.use_ssl = true

request = Net::HTTP::Post.new("/repos/#{gh_user}/#{gh_repo}/releases")
request["Accept"] = "application/vnd.github.v3+json"
request["Authorization"] = "token #{gh_token}"
request.body = {
    "tag_name"         => release_name,
    "target_commitish" => "",
    "name"             => release_name,
    "body"             => "",
    "draft"            => false,
	"prerelease"       => false,
}.to_json

response = http.request(request)

if response.body.include? "already_exist"
    puts "Already exists"
else 
    abort response.body unless response.is_a?(Net::HTTPSuccess)
end

release = JSON.parse(response.body)
#puts release
