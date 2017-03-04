class Place
	include ActiveModel::Model
	attr_accessor :id, :formatted_address, :location, :address_components

=begin
		a read/write (String) attribute called id
		• a read/write (String) attribute called formatted_address
		• a read/write (Point) attribute called location
		• a read/write (collection of AddressComponents) attribute called address_components
		• an initialize method to Place that can set the attributes from a hash with keys _id, address_components,
		  formatted_address, and geometry.geolocation. (Hint: use .to_s to convert a BSON::ObjectId to a
		  String and BSON::ObjectId.from_string(s) to convert it back again.)

		{"_id":BSON::ObjectId(’56521833e301d0284000003d’),
		"address_components":
			[
			{"long_name":"Wilsden", "short_name":"Wilsden", "types":["administrative_area_level_4", "political"]},
			{"long_name":"Bradford District", "short_name":"Bradford District", "types":["administrative_area_level_3", "political"]}
			],
		"formatted_address":"Wilsden, West Yorkshire, UK",
		"geometry":
			{
			"location":{"lat":"53.8256035, "lng":-1.8625303},
			"geolocation":{"type":"Point", "coordinates":[-1.8625303, 53.8256035]}
			}
}


=end
  def initialize(params)
    @id = params[:_id].to_s

    @address_components = []
    if !params[:address_components].nil?
      address_components = params[:address_components]
      address_components.each { |a| @address_components << AddressComponent.new(a) }
    end
    

    @formatted_address = params[:formatted_address]
    @location = Point.new(params[:geometry][:geolocation])
  end



  # tell Rails whether this instance is persisted
  def persisted?
    !@id.nil?
  end

  def created_at
    nil
  end

  def updated_at
    nil
  end

  # convenience method for access to client in console
  def self.mongo_client
   Mongoid::Clients.default
  end

  # convenience method for access to zips collection
  def self.collection
   self.mongo_client['places']
  end

=begin 
  Implement a class method called load_all that will bulk load a JSON document with places information into
  the places collection. This method must
  • accept a parameter of type IO with a JSON string of data
  • read the data from that input parameter (Note: this is similar handling an uploaded file within Rails)
  • parse the JSON string into an array of Ruby hash objects representing places (Hint: JSON.parse)
  • insert the array of hash objects into the places collection (Hint: insert_many)
=end
  def self.load_all(f)
    h = JSON.parse(f.read)
    collection.insert_many(h)
  end

=begin 
  Implement a class method called find_by_short_name that will return a Mongo::Collection::View with a
  query to match documents with a matching short_name within address_components. This method must:
  • accept a String input parameter
  • find all documents in the places collection with a matching address_components.short_name
  • return the Mongo::Collection::View result
=end
  def self.find_by_short_name(s)
    Place.collection.find({"address_components.short_name": s})
  end

=begin
  Implement a helper class method called to_places that will accept a Mongo::Collection::View and return a
  collection of Place instances. This method must:
  • accept an input parameter
  • iterate over contents of that input parameter
  • change each document hash to a Place instance (Hint: Place.new)
  • return a collection of results containing Place objects
=end  
  def self.to_places mcv
    p = []
    mcv.each { |m| 
      p << Place.new(m) 
    }
    return p
  end
	
=begin
  Implement a class method called find that will return an instance of Place for a supplied id. This method must:
  • accept a single String id as an argument
  • convert the id to BSON::ObjectId form (Hint: BSON::ObjectId.from_string(s))
  • find the document that matches the id
  • return an instance of Place initialized with the document if found (Hint: Place.new)
=end  
  def self.find params
    p = collection.find(:_id => BSON::ObjectId.from_string(params)).first
    if !p.nil?
      Place.new(p)
    else
      nil
    end
  end

  def self.all(offset=0, limit=nil)
    if !limit.nil?
      docs = collection.find.skip(offset).limit(limit)
    else
      docs = collection.find.skip(offset)
    end

    docs.map { |doc|
      Place.new(doc)
    }

  end

  def destroy
    self.class.collection.find(:_id => BSON::ObjectId.from_string(@id)).delete_one
  end

=begin
  Create a Place class method called get_address_components that returns a collection of hash documents with
  address_components and their associated _id, formatted_address and location properties. Your method
  must:
  • accept optional sort, offset, and limit parameters
  • extract all address_component elements within each document contained within the collection (Hint: $unwind)
  • return only the _id, address_components, formatted_address, and geometry.geolocation elements (Hint: $project)
  • apply a provided sort or no sort if not provided (Hint: $sort and q.pipeline method)
  • apply a provided offset or no offset if not provided (Hint: $skip and q.pipeline method)
  • apply a provided limit or no limit if not provided (Hint: $limit and q.pipeline method)
  • return the result of the above query (Hint: collection.find.aggregate(...))
=end
  def self.get_address_components(sort = nil, offset = nil, limit = nil)
    pipeline = [
      {:$unwind => "$address_components"},
      {:$project => {address_components: 1, formatted_address: 1, geometry: {geolocation: 1}}}
    ]

    pipeline << {:$sort => sort} unless sort.nil?
    pipeline << {:$skip => offset} unless offset.nil?
    pipeline << {:$limit => limit} unless limit.nil?

    collection.find.aggregate pipeline
  end

=begin 
  Create a Place class method called get_country_names that returns a distinct collection of country names (long_names). Your method must:
  • accept no arguments
  • create separate documents for address_components.long_name and address_components.types (Hint:$project and $unwind)
  • select only those documents that have a address_components.types element equal to "country" (Hint:$match)
  • form a distinct list based on address_components.long_name (Hint: $group)
  • return a simple collection of just the country names (long_name). You will have to use application code to
  do this last step. (Hint: .to_a.map {|h| h[:_id]})
=end
  def self.get_country_names
    collection.find.aggregate([
      {:$project => {_id: 0, address_components: {long_name: 1, types: 1}}},
      {:$unwind => "$address_components"},
      {:$unwind => "$address_components.types"},
      {:$match => {"address_components.types" => "country"}},
      {:$group => {:_id=>"$address_components.long_name"}}]).to_a.map {|h| h[:_id]}
  end

=begin 
  Create a Place class method called find_ids_by_country_code that will return the id of each document in
  the places collection that has an address_component.short_name of type country and matches the provided
  parameter. This method must:
  • accept a single country_code parameter
  • locate each address_component with a matching short_name being tagged with the country type (Hint: $match)
  • return only the _id property from the database (Hint: $project)
  • return only a collection of _ids converted to Strings (Hint: .map {|doc| doc[:_id].to_s})
=end
  def self.find_ids_by_country_code country_code
    collection.find.aggregate([
      {:$unwind => "$address_components"},
      {:$match => {
        "address_components.short_name" => country_code,
        "address_components.types" => "country"
        }
      },
      {:$group => {_id: "$_id"}},
      {:$project => {_id: 1}}
    ]).to_a.map {|doc| doc[:_id].to_s}
  end

  def self.create_indexes
    collection.indexes.create_one("geometry.geolocation" => Mongo::Index::GEO2DSPHERE)
  end

  def self.remove_indexes
    collection.indexes.drop_one("geometry.geolocation_2dsphere")
  end

=begin 
  Create a Place class method called near that returns places that are closest to provided Point. This method
  must:
  • accept an input parameter of type Point (created earlier) and an optional max_meters that defaults to no maximum
  • performs a $near search using the 2dsphere index placed on the geometry.geolocation property and the GeoJSON output of point.to_hash (created earlier). (Hint: Query a 2dsphere Index)
  • limits the maximum distance – if provided – in determining matches (Hint: $maxDistance)
  • returns the resulting view (i.e., the result of find())
  You can demonstrate your new class methods using the Rails console. You can use one of a number of queries
  to locate a specific document within the places collection and then create a Place instance to represent that
  document.

  Sample Point:
    => #<Point:0x000000036aff10 @latitude=39.874572, @longitude=-75.56709699999999>

  pa_point.to_hash
    => {:type=>"Point", :coordinates=>[-75.56709699999999, 39.874572]}

=end
  def self.near(point, max_meters = 0)
    collection.find('geometry.geolocation' => {:$near => {:$geometry => point.to_hash, :$maxDistance => max_meters}})
  end

=begin 
  Create an instance method (also) called near that wraps the class method you just finished. This method must:
  • accept an optional parameter that sets a maximum distance threshold in meters
  • locate all places within the specified maximum distance threshold
  • return the collection of matching documents as a collection of Place instances using the to_places class
  method added earlier.
=end
  def near(max_meters = 0)
    Place.to_places(Place.near(@location.to_hash, max_meters))
  end

=begin 
Add a new instance method called photos to the Place model class. This method will return a collection of
  Photos that have been associated with the place. This method must:
  • accept an optional set of arguments (offset, and limit) to skip into and limit the result set. The offset
    should default to 0 and the limit should default to unbounded.
=end
  def photos(offset = 0, limit = 0)
    photos = Photo.find_photos_for_place(@id).skip(offset).limit(limit)
    photos.map {|photo| Photo.new(photo)}
  end
end

