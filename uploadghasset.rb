#!/usr/bin/env ruby

if ARGV.length < 2
  abort "\nError: The tag and file name are required. Aborting...\n\n"
end

require 'octokit'
 
USER='getlantern'
PROJECT='flashlight-build'

TAG=ARGV[0]
FILE_NAME=ARGV[1]

@client = Octokit::Client.new(:access_token => ENV['GH_TOKEN'])


def release(file, tag) 
  releases = @client.releases "#{USER}/#{PROJECT}"
  target_release = releases.select { |r| r.tag_name == tag }[0]

  assets = @client.release_assets(target_release.url)
  if not assets.empty?
    assets.each do |asset|
      $stderr.puts "* Removing #{asset.name} (#{asset.content_type})..."
	  @client.delete_release_asset(asset.url)
    end	
  end

  begin
    #ct = MIME::Types.of(file).first || "application/octet-stream"
    @client.upload_asset(target_release.url, file)
  rescue Octokit::UnprocessableEntity
    abort "\nEntity already exists? Should never happen\n"
  end
end

release("#{FILE_NAME}", "#{TAG}")

