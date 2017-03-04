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

  def self.find(id)
    doc = mongo_client.database.fs.find({_id: BSON::ObjectId.from_string(id)}).first
    Photo.new(doc) unless doc.nil?
  end

  def contents
    file = Photo.mongo_client.database.fs.find_one({:_id=>BSON::ObjectId.from_string(@id)})

    if file
      buffer = ""
      file.chunks.reduce([]) do |x,chunk|
        buffer << chunk.data.data
      end
      return buffer
    end
  end

  def destroy
    Photo.mongo_client.database.fs.find({:_id=>BSON::ObjectId.from_string(@id)}).delete_one
  end

  def find_nearest_place_id max_meters
    options = {'geometry.geolocation' => {:$near => @location.to_hash}}
    Place.collection.find(options).limit(1).projection({_id: 1}).first[:_id]
  end

  def place
    Place.find(@place.to_s) unless @place.nil?
  end

  def place= object
    @place = object
    @place = BSON::ObjectId.from_string(object) if object.is_a? String
    @place = BSON::ObjectId.from_string(object.id) if object.respond_to? :id
  end

  def self.find_photos_for_place id
    mongo_client.database.fs.find({'metadata.place' => BSON::ObjectId.from_string(id)})
  end

end