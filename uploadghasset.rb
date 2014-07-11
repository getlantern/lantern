#!/usr/bin/env ruby

require 'octokit'
 
USER='getlantern'
PROJECT='lantern'

TAG=ARGV[0]
FILE_NAME=ARGV[1]

client = Octokit::Client.new(:access_token => ENV['GH_TOKEN'])

releases = client.releases "#{USER}/#{PROJECT}"

target_release = releases.select { |r| r.tag_name == "#{TAG}" }[0]

client.upload_asset(target_release.url, "#{FILE_NAME}") 

