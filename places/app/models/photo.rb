class Photo
  
=begin 
		 Implement the following attributes in the Photo class
			• a read/write attribute called id that will be of type String to hold the String form of the GridFS file _id attribute
			• a read/write attribute called location that will be of type Point to hold the location information of where the photo was taken.
			• a write-only (for now) attribute called contents that will be used to import and access the raw data of the photo. 
			  This will have varying data types depending on context.
=end
  attr_accessor :id, :location, :contents, :place


=begin 
	Add an initialize method in the Photo class that can be used to initialize the instance attributes of Photo
	from the hash returned from queries like mongo_client.database.fs.find. This method must
	• initialize @id to the string form of _id and @location to the Point form of metadata.location if these exist.
	  The document hash is likely coming from query results coming from mongo_client.database.fs.find.
	• create a default instance if no hash is present
=end
  def initialize(params = nil)
    @id = params[:_id].to_s unless params.nil?
    @location = Point.new(params[:metadata][:location]) unless params.nil?
    @place = params[:metadata][:place] unless params.nil?
  end


  def self.mongo_client
    Mongoid::Clients.default
  end

  def persisted?
    !@id.nil?
  end

=begin 
	Add an instance method to the Photo class called save to store a new instance into GridFS. This method must:
	• check whether the instance is already persisted and do nothing (for now) if already persisted (Hint: use your new persisted? method to determine if your instance has been persisted)
	• use the exifr gem to extract geolocation information from the jpeg image.
	• store the content type of image/jpeg in the GridFS contentType file property.
	• store the GeoJSON Point format of the image location in the GridFS metadata file property and the object in class’ location property.
	• store the data contents in GridFS
	• store the generated _id for the file in the :id property of the Photo model instance.

	Update the logic within the existing save instance method to update the file properties (not the file data – just
	the file properties/metadata) when called on a persisted instance. Previously, the method only handled a new
	Photo instance that was yet persisted. This method must:
	• accept no inputs
	• if the instance is not yet persisted, perform the existing logic to add the file to GridFS
	• if the instance is already persisted (Hint: persisted? helper method added earlier) update the file info
	  (Hint: find(...).update_one(...))
=end
  def save
    if !persisted?
      gps = EXIFR::JPEG.new(@contents).gps
      location = Point.new(lng: gps.longitude, lat: gps.latitude)
      @contents.rewind
      description = {}
      description[:metadata] = {location: location.to_hash, place: @place}
      description[:content_type] = "image/jpeg"
      @location = Point.new(location.to_hash)
      grid_file = Mongo::Grid::File.new(@contents.read, description)
      @id = Place.mongo_client.database.fs.insert_one(grid_file).to_s
    else
      doc = Photo.mongo_client.database.fs.find({_id: BSON::ObjectId.from_string(@id)}).first
      doc[:metadata][:place] = @place
      doc[:metadata][:location] = @location.to_hash
      Photo.mongo_client.database.fs.find({_id: BSON::ObjectId.from_string(@id)}).update_one(doc)
    end
  end

=begin 
	Add a class method to the Photo class called all. This method must:
	• accept an optional set of arguments for skipping into and limiting the results of a search
	• default the offset (Hint: skip) to 0 and the limit to unlimited
	• return a collection of Photo instances representing each file returned from the database (Hint: ...find.map
	  {|doc| Photo.new(doc) })
=end
  def self.all(offset = 0,limit = 0)
    mongo_client.database.fs.find.skip(offset).limit(limit).map {|doc| Photo.new(doc)}
  end

=begin 
	Create a class method called find that will return an instance of a Photo based on the input id. This method
	must:
	• accept a single String parameter for the id
	• locate the file associated with the id by converting it back to a BSON::ObjectId and using in an :_id query.
	• set the values of id and location witin the model class based on the properties returned from the query.
	• return an instance of the Photo model class
=end
  def self.find(id)
    doc = mongo_client.database.fs.find({_id: BSON::ObjectId.from_string(id)}).first
    Photo.new(doc) unless doc.nil?
  end

=begin 
Create a custom getter for contents that will return the data contents of the file. This method must:
• accept no arguments
• read the data contents from GridFS for the associated file
• return the [aka size of the file, in] data bytes
=end
  def contents
    f = Photo.mongo_client.database.fs.find_one({:_id=>BSON::ObjectId.from_string(@id)})

    if f
      buffer = ""
      f.chunks.reduce([]) do |x,chunk|
        buffer << chunk.data.data
      end
      return buffer
    end
  end

  def destroy
    Photo.mongo_client.database.fs.find({:_id=>BSON::ObjectId.from_string(@id)}).delete_one
  end


=begin 
	Create a Photo helper instance method called find_nearest_place_id that will return the _id of the document
	within the places collection. This place document must be within a specified distance threshold of where the photo was taken. This Photo method must:
	• accept a maximum distance in meters
	• uses the near class method in the Place model and its location to locate places within a maximum distance of where the photo was taken.
	• limit the result to only the nearest matching place (Hint: limit())
	• limit the result to only the _id of the matching place document (Hint: projection())
	• returns zero or one BSON::ObjectIds for the nearby place found
=end
  def find_nearest_place_id max_meters
    options = {'geometry.geolocation' => {:$near => @location.to_hash}}
    Place.collection.find(options).limit(1).projection({_id: 1}).first[:_id]
  end

=begin 
	We will be adding to Photo the functionality to support a relationship with Place. Add a new place attribute
	in the Photo class to be used to realize a Many-to-One relationship between Photo and Place. The Photo class
	must:
	• add support for a place instance attribute in the model class. You will be implementing a custom setter/getter for this attribute
	• store this new property within the file metadata (metadata.place)
	• update the initialize method to cache the contents of metadata.place in an instance attribute called @place
	• update the save method to include the @place and @location properties under the parent metadata property in the file info.
	• add a custom getter for place that will find and return a Place instance that represents the stored ID (Hint: Place.find)
	• add a custom setter that will update the place ID by accepting a BSON::ObjectId, String, or Place instance.
	  In all three cases you will want to derive a a BSON::ObjectId from what is passed in.
=end
#============================================================================
#Getter
  def place
    Place.find(@place.to_s) unless @place.nil?
  end

#Getter
  def place= object
    @place = object
    @place = BSON::ObjectId.from_string(object) if object.is_a? String
    @place = BSON::ObjectId.from_string(object.id) if object.respond_to? :id
  end
#============================================================================


=begin 
	Add a class method called find_photos_for_place that accepts the BSON::ObjectId of a Place and returns a
	collection view of photo documents that have the foreign key reference. This method must:
	• accept the ID of a place in either BSON::ObjectId or String ID form (Hint: BSON::ObjectId.from_string(place_id.to_s)
	• find GridFS file documents with the BSON::ObjectId form of that ID in the metadata.place property.
	• return the result view
=end
  def self.find_photos_for_place id
    mongo_client.database.fs.find({'metadata.place' => BSON::ObjectId.from_string(id)})
  end

end