#!/usr/bin/env ruby

if ARGV.length < 4
  abort "\nUsage upload_asset.rb $GH_USER $GH_PROJECT $TAG $FILE_NAME\n\n"
end

require 'octokit'

USER=ARGV[0]
PROJECT=ARGV[1]
TAG=ARGV[2]
FILE_NAME=ARGV[3]

@client = Octokit::Client.new(:access_token => ENV['GH_TOKEN'])

def release(file, tag)
  releases = @client.releases "#{USER}/#{PROJECT}"
  target_release = releases.select { |r| r.tag_name == tag }[0]

  begin
    #ct = MIME::Types.of(file).first || "application/octet-stream"
    @client.upload_asset(target_release.url, file)
  rescue Octokit::UnprocessableEntity
    abort "\nEntity already exists? Should never happen\n"
  end
end

release("#{FILE_NAME}", "#{TAG}")

