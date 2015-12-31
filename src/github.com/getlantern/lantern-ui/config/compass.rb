Encoding.default_external = "utf-8"
BASEDIR = File.expand_path(File.join(File.dirname(__FILE__), '..'))

http_path = '/'
project_path = File.join(BASEDIR, 'app')
sass_path = File.join(project_path, 'scss')
css_dir = '_css'
fonts_dir = 'font'
images_dir = 'img'
javascripts_dir = 'js'
output_style = :expanded
environment = :production
relative_assets = true
preferred_syntax = :scss
asset_cache_buster :none
sourcemap=true
