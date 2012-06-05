# encoding : UTF-8

require "RMagick"
require "json"
require "yaml"

module Nesta
   
  module Plugin
    module Gallery
      module Helpers
        # returns all images of selected gallery with descriptions if provided
        # @return Array of Hashes
		def get_images(gallery_name)
			Gallery.get_images(gallery_name)
		end

        # returns all galleries described in galleries.yml
        # @return Hash
		def get_galleries
			Gallery.get_galleries
		end

        # returns image resized to fit provided resolution with method selected in config.yml
        # @return Hash or String
        def get_image(gallery, name, width, height)
            Gallery.get_image(gallery, name, width, height)
        end

      end

        # default config
        WIDTH_RESOLUTIONS_DEFAULT = Array.[](320, 360, 480, 640, 768, 800, 960, 1024, 1152, 1280, 1366, 1600, 1980)
        HEIGHT_RESOLUTIONS_DEFAULT = Array.[](240, 360, 480, 480, 768, 600, 960, 1024, 1152, 1280, 1366, 1600, 1980)
        RESIZE_METHOD_DEFAULT = "closest"
        IMAGE_RETURN_METHOD_DEFAULT = "url"

		CONTENT_DIRECTORY = Nesta::Config.content
		GALLERIES_DIRECTORY = Nesta::Config.attachment_path + "/gallery/"

        # loads config file - config.yml
        def self.load_config
            data = Hash.new

            if File.exists?(GALLERIES_DIRECTORY + "config.yml")
                config = YAML::load(File.open(GALLERIES_DIRECTORY + "config.yml"))

                data["width_resolutions"] = config.has_key?("width_resolutions") ? config["width_resolutions"] : WIDTH_RESOLUTIONS_DEFAULT
                data["height_resolutions"] = config.has_key?("height_resolutions") ? config["height_resolutions"] : HEIGHT_RESOLUTIONS_DEFAULT
                data["resize_method"] = config.has_key?("resize_method") ? config["resize_method"] : RESIZE_METHOD_DEFAULT
                data["image_return_method"] = config.has_key?("image_return_method") ? config["image_return_method"] : IMAGE_RETURN_METHOD_DEFAULT 
            else
                data["width_resolutions"] = WIDTH_RESOLUTIONS_DEFAULT
                data["height_resolutions"] = HEIGHT_RESOLUTIONS_DEFAULT
                data["resize_method"] = RESIZE_METHOD_DEFAULT
                data["image_return_method"] = IMAGE_RETURN_METHOD_DEFAULT
            end

            return data
        end

		def self.get_galleries
			return Array.new unless File.exist?(GALLERIES_DIRECTORY + "galleries.yml")

			yml = YAML::load(File.open(GALLERIES_DIRECTORY + "galleries.yml"))

			return Array.new if yml.empty?

            list = Array.new
            yml.each do |name, data|
                list.push data
            end

			return list
		end

		def self.get_images(gallery)
            config = load_config
			path = GALLERIES_DIRECTORY + gallery
            
            # gallery does not exist
			unless File.directory? path
				return Array.new
			end
			
			files = Dir.glob(path + '/full/*') 
		
            # there are no files in gallery
			return Array.new if files.empty?

            images = Array.new

            # gets descriptions for sellected gallery
            if File.exists?(path + "/images.txt")
                descriptions = Hash.new
                desc = File.open(path + "/images.txt", "r", :encoding => "UTF-8")

                desc.each_line do |line|
                    split = line.split(';')
                    descriptions[split[0]] = split[1].chomp
                end
            end

            # gets all images from gallery and adds description
            files.each do |file|
                image = Hash.new
                file = Pathname.new(file).relative_path_from(Pathname.new(path + "/full/")).to_s
                image["file"] = file
				if descriptions
						if descriptions.has_key?(file)
							image["description"] = descriptions[file]
						end
				else
					image["description"] = ""
				end

                images.push image
            end
                    
			return images
		end

        def self.get_image(gallery, image, width, height)
            path = GALLERIES_DIRECTORY + gallery + "/"

            full = path + "full/" + image

            # image does not exist
            return Hash.new unless File.exists?(full)

            if height == 0 and width == 0 
                return get_image_data(full) 
            end

            unless width == 0
                resolution_width = closest_resolution(width, true)
            end

            unless height == 0 
                resolution_height = closest_resolution(height, false)
            end

            folder = "#{resolution_width}-#{resolution_height}/"

            # full path for image
            small = path + folder + image

            # image was not resized for required resolution
            unless File.exists?(small)
                # resize it
                resize_image(gallery, image, resolution_width, resolution_height)
            end

            return get_image_data(small)
        end

        # returns image data based on config
        def self.get_image_data(file)
            config = load_config()
            if config["image_return_method"] == "hash"
                # get image data
                image = Magick::Image::read(file).first

                data = Hash.new

                # return image name, width and height
                data["file"] = Pathname.new(file).relative_path_from(Pathname.new(CONTENT_DIRECTORY)).to_s
                data["width"] = image.columns
                data["height"] = image.rows


                return data
            else
                return Pathname.new(file).relative_path_from(Pathname.new(CONTENT_DIRECTORY)).to_s
            end
        end

		# choses the best fitting resolution
		def self.closest_resolution(size, width)

            config = load_config()
            
            if width 
                resolutions = config["width_resolutions"] 
            else
                resolutions = config["height_resolutions"] 
            end

            case config["resize_method"]
                when "bigger"
                    resolutions.sort!
                    resolutions.each do |res|
                        if res >= size
                            return res
                        end
                    end
                    return res

                when "smaller"
                    resolutions.sort!
                    prev = resolutions.first
                    resolutions.each do |res|
                        if res > size
                            return prev
                        end
                        prev = res
                    end
                    return res

                when "closest"
                    diff = resolutions.max
                    resolution = 0

                    resolutions.each do |res|
                        newdiff = (res - size).abs
            
                        if newdiff < diff
                            resolution = res
                            diff = newdiff
                        end
                    end
                    return resolution
                default
                    raise "Nesta plugin gallery error. Can't recognize selected resize type #{config["resize_type"]}"
            end
		end

        # returns true if image is landscape
        def self.is_landscape?(file)
            image = Magick::Image::read(file).first

            landscape = (image.columns / image.rows) >= 0 ? true : false

            return landscape
        end

		# resizes image by provided width and height
		def self.resize_image(gallery, image, width, height)
			path = GALLERIES_DIRECTORY + gallery + "/"

			file = path + "full/" + image
			
            image = Magick::Image::read(file).first

            # resize image to fit selected resolution
            new = image.resize_to_fit!(width.to_i, height.to_i)

            # get only file name without full path
            file = Pathname.new(file).relative_path_from(Pathname.new(path + "full")).to_s

            newdir = "#{width}-#{height}"

            Dir.mkdir(path + newdir) unless File.directory?(path + newdir)
            new.write(path + newdir + "/" + file)
		end
    end
  end
	

  class App
    helpers Nesta::Plugin::Gallery::Helpers
  end
end
