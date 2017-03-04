# This file should contain all the record creation needed to seed the database with its default values.
# The data can then be loaded with the rake db:seed (or created alongside the db with db:setup).
#
# Examples:
#
#   cities = City.create([{ name: 'Chicago' }, { name: 'Copenhagen' }])
#   Mayor.create(name: 'Emanuel', city: cities.first)


=begin 
	In this section you must implement a data initialization/population script in db/seeds.rb that will be runnable from
	the operating system shell using $ rake db:seed. In this Ruby script, you must clear the database of existing records,
	ingest the Places and Photos, and form one-to-many linked relationships between photos and places. This should
	simply be the grand finale of most of the model class capabilities you implemented above in order to populate the data
	tier for use in the follow-on web tier.
	Your seeds.rb must:
	1. Clear GridFS of all files. You may use the model commands you implemented as a part of this assignment or
	   lower-level GridFS or database commands to implement the removal of all files.

	2. Clear the places collection of all documents. You may use the model commands you implemented as a part of
	   this assignment or lower-level collection or database commands to implement the removal of all documents from the places collection.

	3. Make sure the 2dsphere index has been created for the nested geometry.geolocation property within the
	   places collection.

	4. Populate the places collection using the db/places.json file from the provided bootstrap files in student-start.

	5. Populate GridFS with the images also located in the db/ folder and supplied with the bootstrap files in
	   student-start.

	Hint: The following snippet will loop thru the set of images. You must ingest the contents of each of these files as
	      a Photo.
			> Dir.glob("./db/image*.jpg") { |f| p f}
			"./db/image3.jpg"
			...
			"./db/image2.jpg"

	6. For each photo in GridFS, locate the nearest place within one (1) mile of each photo and associated the photo
	   with that place. (Hint: make sure to convert miles to meters for the inputs to the search).

	7. As a self-test, verify that you have the following places – shown by their formatted address – associated with a
	   photo and can locate this association with a reference to the place.
=end

require 'pp'
Photo.all.each { |photo| photo.destroy }
Place.all.each { |place| place.destroy }
Place.create_indexes
Place.load_all(File.open('./db/places.json'))
Dir.glob("./db/image*.jpg") {|f| photo=Photo.new; photo.contents=File.open(f,'rb'); photo.save}
Photo.all.each {|photo| place_id=photo.find_nearest_place_id 1*1609.34; photo.place=place_id; photo.save}
pp Place.all.reject {|pl| pl.photos.empty?}.map {|pl| pl.formatted_address}.sort
