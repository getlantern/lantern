gem 'compass_twitter_bootstrap', '=2.2.2.2'
require 'compass_twitter_bootstrap'

BASEDIR = File.absolute_path(File.join(File.dirname(__FILE__), '..'))

http_path = '/'
project_path = File.join(BASEDIR, 'app')
sass_path = File.join(BASEDIR, 'sass')
css_dir = '_css'
fonts_dir = 'font'
images_dir = 'img'
javascripts_dir = 'js'
output_style = :expanded
environment = :production
relative_assets = true
preferred_syntax = :sass
asset_cache_buster :none
