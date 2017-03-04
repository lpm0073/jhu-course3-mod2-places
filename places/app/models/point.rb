class Point
	attr_accessor :longitude, :latitude

	#example params
	#GeoJSON Point format: 	{"type":"Point", "coordinates":[-1.8625303, 53.8256035]} 
	#Alt format 			{"lat":53.8256035, "lng":-1.8625303}
	def initialize(params)
		if params[:type] && params[:type] == "Point"
			@longitude = params[:coordinates][0]
			@latitude = params[:coordinates][1]
		else
			@longitude = params[:lng]
			@latitude = params[:lat]
		end
	end

def to_hash
	{:type=>"Point",:coordinates=>[@longitude, @latitude]}
end

end