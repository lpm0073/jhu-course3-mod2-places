class AddressComponent
	attr_reader :long_name, :short_name, :types

	#Example params: {"long_name":"Bradford District",
	#				  "short_name":"Bradford District",
	#				  "types":["administrative_area_level_3", "political"]
	# 				 },
	def initialize(params)
		@long_name = params[:long_name]
		@short_name = params[:short_name]
		@types = params[:types]
	end

end