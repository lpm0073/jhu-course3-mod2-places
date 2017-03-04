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

end

