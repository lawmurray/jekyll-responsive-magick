Gem::Specification.new do |s|
  s.name        = "jekyll-responsive-magick"
  s.version     = "1.0.2"
  s.summary     = "A Jekyll plugin for responsive images using ImageMagick. Works with Jekyll 4."
  s.description = "A Jekyll plugin for responsive images. Adds filters for setting the srcset, width and height attributes of HTML img elements, while automatically generating image variants of configured sizes using the ImageMagick command-line tools. Resized images are cached to minimize build times, regenerated only when the original source image changes."
  s.authors     = ["Lawrence Murray"]
  s.email       = "lawrence@indii.org"
  s.files       = ["lib/jekyll-responsive-magick.rb", 'LICENSE']
  s.homepage    = "https://indii.org/software/jekyll-responsive-magick"
  s.license       = "Apache-2.0"
  s.required_ruby_version = '>= 2.5'
end
