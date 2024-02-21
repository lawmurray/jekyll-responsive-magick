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
require 'filemagic'

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
    def image_mime_type?(src)
      mime = FileMagic.new(FileMagic::MAGIC_MIME).file(src)
      return mime.start_with?('image/')
    end 

    def srcset(input)
      site = @context.registers[:site]
      check_path(input, "srcset")
      dirname = File.dirname(input)
      basename = File.basename(input, '.*')
      extname = File.extname(input)
      src = ".#{dirname}/#{basename}#{extname}"
      srcwidth = width(input, "srcset")      
      srcset = ["#{input} #{srcwidth}w"]

      if File.exist?(src) and ['.jpg', '.jpeg', '.png', '.apng', '.gif'].include?(extname)
        dest = site.dest
        if site.config['responsive']['widths']
          widths = site.config['responsive']['widths']
        else
          # as default, use breakpoints of Bootstrap 5
          widths = [576,768,992,1200,1400]
        end
        if site.config['responsive']['quality']
          quality = site.config['responsive']['quality']
        else
          quality = 80
        end
        if site.config['responsive']['verbose']
          verbose = site.config['responsive']['verbose']
        else
          verbose = false
        end
        
        widths.map do |width|
          if srcwidth > width
            file = "#{basename}-#{width}w#{extname}"
            dst = "_responsive#{dirname}/#{file}"
            if not site.static_files.find{|file| file.path == dst}
              site.static_files << StaticFile.new(site, "_responsive", dirname, file)
              if not File.exist?(dst) or File.mtime(src) > File.mtime(dst)
                FileUtils.mkdir_p(File.dirname(dst))
                if extname == '.apng'
                  cmd = "convert apng:#{src.shellescape} -strip -quality #{quality} -resize #{width} #{dst.shellescape}"
                else
                  cmd = "convert #{src.shellescape} -strip -quality #{quality} -resize #{width} #{dst.shellescape}"
                end
                if verbose
                  print("#{cmd}\n")
                end
                if not system(cmd)
                  throw "srcset: failed to execute 'convert', is ImageMagick installed?"
                end
              end
            end
            srcset.push("#{dirname}/#{file} #{width}w")
          end
        end
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
      site = @context.registers[:site]
      check_path(input, "size")
      dirname = File.dirname(input)
      basename = File.basename(input, '.*')
      extname = File.extname(input)
      src = ".#{dirname}/#{basename}#{extname}"

      if site.config['responsive']['quality']
        quality = site.config['responsive']['quality']
      else
        quality = 80
      end
      if site.config['responsive']['verbose']
        verbose = site.config['responsive']['verbose']
      else
        verbose = false
      end

      if File.exist?(src) and ['.jpg', '.jpeg', '.png', '.apng', '.gif'].include?(extname)
        file = "#{basename}-#{width}w#{extname}"
        dst = "_responsive#{dirname}/#{file}"
        if not site.static_files.find{|file| file.path == dst}
          site.static_files << StaticFile.new(site, "_responsive", dirname, file)
          if not File.exist?(dst) or File.mtime(src) > File.mtime(dst)
            FileUtils.mkdir_p(File.dirname(dst))
            if extname == '.apng'
              cmd = "convert apng:#{src.shellescape} -strip -quality #{quality} -resize #{width} #{dst.shellescape}"
            else
              cmd = "convert #{src.shellescape} -strip -quality #{quality} -resize #{width} #{dst.shellescape}"
            end
            if verbose
              print("#{cmd}\n")
            end
            if not system(cmd)
              throw "size: failed to execute 'convert', is ImageMagick installed?"
            end
          end
        end
      end

      return "#{dirname}/#{file}"
    end
  end
end

Liquid::Template.register_filter(Jekyll::ResponsiveMagickFilter)
