Nesta Gallery
=============

Gallery plugin for NestaCMS

Provides helpers for creating simple gallery in Nesta CMS with automated image resizing.
##Installation

Place plugin into `nesta-plugin-gallery` folder in root of your NestaCMS and add this into `Gemfile`

	gem "nesta-plugin-gallery",	:path => "nesta-plugin-gallery"

Create folder `gallery` in attachments folder inside your content folder (Nesta gallery gets content path automatically).
Create file called `galleries.yml` which includes description of galleries inside `gallery` folder.

	# galleries.yml example
	Gallery:
	    name: Testing gallery
		    folder: gallery
	Gallery2:
		name: Testing gallery
		folder: gallery2

(optional) Create file called `config.yml` inside `gallery` folder. If there is no config file, default values are used.
	
	# config.yml example
	
	# default resolutions are used if not provided
	width_resolutions: [1024, 1280, 1680]
	height_resolutions: [768, 800, 1050]

	# closest, smaller, bigger
	# closest: returns image with closest resolution
	# smaller: returns image with smaller resolution
	# bigger: returns image with bigger resolution
	# default (closest) is used if not provided
	resize_method: closest

	# url, hash 
	# url: returns image url
	# hash: returns hash with url, width and height of image - for JSON use
	# default (url) is used if not provided
	image_return_method: url
	
Create folder for every gallery described in your `galleries.yml` file inside `attachments/gallery` folder. Every gallery folder must contain `full` folder with images in the biggest resolution.

(optional) You may want to add description for some of your images. If so, place file called `images.txt` inside your gallery/gallery-name folder with description for images you want to.

	# images.txt example
	file-name.png; Description for image
	grandma.jpg; Coolest grandma ever!

**images.txt can contain only lines with descriptions!**

##API
	
`get_galleries()`

Returns Hash of galleries described in `galleries.yml` 

	# get_galleries output converted to JSON
	# format gallery_folder: description

	{
		gallery: "Testing gallery",
		gallery2: "Testing gallery"
	}


`get_images(gallery_folder)`

Returns array of hashes of all image names from selected gallery with descriptions.

	# get_images output converted to JSON
	[
		- {
			file: "file-name.png",
			description: "Description for image"
		}
		- {
			file: "grandma.jpg",
			description: "Coolest grandma ever!"
		}
		- {
			file: "image-without-description.jpg"
		}
	]

`get_image(gallery_folder, image_name, width, height)`

Returns String for path or Hash with additional info about file(depends on config). Also resizes image if width and/or height is provided to fit provided resolutions and selected resize type (both based on config).

Resized file is saved into gallery folder in folder named as width-height.
	
	# get_image Hash output called provided with width only in JSON
	{
		file: "attachments/gallery/gallery2/800-/grandma.png",
		width: 800,
		height: 800
	}

	# get_image String output provided with no resolutions
	attachments/gallery/gallery2/full/grandma.png

##Tips

Way I use Nesta Gallery with custom routes

	# app.rb
	module Nesta
		class App
			get "/galleries" do
				content_type :json
				get_galleries.to_json
			end

			get "/gallery/:name" do
	            content_type :json
				get_images(params[:name]).to_json
			end

	        get "/gallery/:name/:image" do
	            content_type :json
	            get_image(params[:name], params[:image], params[:width].to_i, params[:height].to_i).to_json
	        end
		end
	end

Which gives me URL API like this

	/galleries - returns list of galleries in JSON
	/gallery/gallery-name - returns list of images from selected gallery in JSON
	/gallery/gallery-name/image-name.png?width=xx&height=xx - resizes selected image and returns its path

