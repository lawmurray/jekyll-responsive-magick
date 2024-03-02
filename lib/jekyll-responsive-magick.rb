##
## A Jekyll plugin for responsive images with ImageMagick.
##
##    https://indii.org/software/jekyll-responsive-magick/
##
## Copyright 2022 Lawrence Murray.
##
## Licensed under the Apache License, Version 2.0 (the "License");
## you may not use this file except in compliance with the License.
## You may obtain a copy of the License at
##
##    http://www.apache.org/licenses/LICENSE-2.0
##
## Unless required by applicable law or agreed to in writing, software
## distributed under the License is distributed on an "AS IS" BASIS,
## WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
## See the License for the specific language governing permissions and
## limitations under the License.
##
require 'fileutils'
require 'shellwords'

module Jekyll
  module ResponsiveMagickFilter
    @@sizes = {}

    def identify(input)
      site = @context.registers[:site]
      if site.config['responsive']['verbose']
        verbose = site.config['responsive']['verbose']
      else
        verbose = false
      end
      cmd = "identify -ping -format '%w,%h' .#{input.shellescape}"
      if verbose
        print("#{cmd}\n")
      end
      sizes = `#{cmd}`
      if not $?.success?
        throw "width/height: failed to execute 'identity', is ImageMagick installed?"
      end
      @@sizes[input] = sizes.split(',', 2).map!(&:to_i)
    end

    # Throw error if it is not an absolute path
    def check_path(input, filter_name)
      if not input.is_a? String || input.length == 0 || input.chr != '/'
        throw "#{filter_name}: path must be an absolute path"
      end
    end

    # Return true if the file exists and is an image mime type
    def is_image?(src)
      cmd = "identify -ping #{src.shellescape} 2>&1"
      output = `#{cmd}`

      if not $?.success?
        if output.include?("identify: improper image header")
          throw "file is not an image: '#{src}'"
        else
          throw "width/height: failed to execute 'identity', is ImageMagick installed?"
        end
      end

      return true
    end

    # Convert an image from src to dst with the given width
    def convert(src, src_extname, dst, width)
      site = @context.registers[:site]      
      quality = site.config['responsive']['quality'] || 80
      verbose = site.config['responsive']['verbose'] || false

      if File.exist?(dst) and File.mtime(src) < File.mtime(dst)
        return
      end

      FileUtils.mkdir_p(File.dirname(dst))
      cmd = "convert #{src_extname == '.apng' ? 'apng:' : ''}#{src.shellescape} -strip -quality #{quality} -resize #{width} #{dst.shellescape}"
      
      if verbose
        print("#{cmd}\n")
      end
      
      if not system(cmd)
        throw "srcset: failed to execute 'convert', is ImageMagick installed?"
      end
    end

    def srcset(input)
      check_path(input, "srcset")
      site = @context.registers[:site]
      dirname = File.dirname(input)
      basename = File.basename(input, '.*')
      extname = File.extname(input)
      new_extname = site.config['responsive']['format'] ? ".#{site.config['responsive']['format']}" : extname
      src = ".#{dirname}/#{basename}#{extname}"
      srcwidth = width(input, "srcset")      
      srcset = ["#{input} #{srcwidth}w"]

      if not File.exist?(src) or not is_image?(src)
        throw "srcset: file does not exist or is not an image: '#{src}'"
      end

      # as default, use breakpoints of Bootstrap 5
      widths = site.config['responsive']['widths'] || [576, 768, 992, 1200, 1400]
      
      widths.map do |width|
        if not srcwidth > width
          next # image is not large enough to generate a smaller version
        end

        file = "#{basename}-#{width}w#{new_extname}"
        dst = "_responsive#{dirname}/#{file}"
        srcset.push("#{dirname}/#{file} #{width}w")

        if site.static_files.find{|file| file.path == dst}
          next # image is already generated
        end
        
        site.static_files << StaticFile.new(site, "_responsive", dirname, file)
        convert(src, extname, dst, width)
      end

      return srcset.join(', ')
    end

    def width(input, from)
      check_size(input, from)
      return @@sizes[input][0]
    end

    def height(input, from)
      check_size(input, from)
      return @@sizes[input][1]
    end

    def check_size(input, from)
      check_path(input, from)
      if not @@sizes[input]
        identify(input)
      end
    end

    def size(input, width)
      check_path(input, "size")
      site = @context.registers[:site]
      dirname = File.dirname(input)
      basename = File.basename(input, '.*')
      extname = File.extname(input)
      new_extname = site.config['responsive']['format'] ? ".#{site.config['responsive']['format']}" : extname
      src = ".#{dirname}/#{basename}#{extname}"

      if not File.exist?(src) or not is_image?(src)
        throw "srcset: file does not exist or is not an image: '#{src}'"
      end
      
      file = "#{basename}-#{width}w#{new_extname}"
      dst = "_responsive#{dirname}/#{file}"
      full_path = "#{dirname}/#{file}"

      if site.static_files.find{|file| file.path == dst}
        return full_path # image is already generated
      end

      site.static_files << StaticFile.new(site, "_responsive", dirname, file)
      convert(src, extname, dst, width)

      return full_path
    end
  end
end

Liquid::Template.register_filter(Jekyll::ResponsiveMagickFilter)
