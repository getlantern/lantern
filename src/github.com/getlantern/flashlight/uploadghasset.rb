#!/usr/bin/env ruby

# This allows us to easily deploy flashlight binaries by tag to GitHub, for example:
# Prerequisites:
#
# 1) gem install octokit
# 2) Obtain an oauth token at https://help.github.com/articles/creating-an-access-token-for-command-line-use
# 3) Set your GH_TOKEN environment variable to that token
#
# ./uploadghasset.rb 0.0.1 ../../../../bin/flashlight-xc/snapshot/linux_amd64/flashlight 
require 'octokit'
 
USER='getlantern'
PROJECT='flashlight'

TAG=ARGV[0]
FILE_NAME=ARGV[1]

client = Octokit::Client.new(:access_token => ENV['GH_TOKEN'])

releases = client.releases "#{USER}/#{PROJECT}"

puts "Releases are: #{releases}"
target_release = releases.select { |r| r.tag_name == "#{TAG}" }[0]

puts "Target release: #{target_release}"
#puts target_release.url
client.upload_asset(target_release.url, "#{FILE_NAME}", content_type: 'application/octet-stream') 

