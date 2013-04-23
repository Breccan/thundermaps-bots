require 'pp'
require 'json'
require 'httparty'
require 'xmlsimple'

class Record
	attr_accessor :library_name, :category_name, :date, :latitude, :longitude, :description, :source_id, :ID
	
	def initialize( library_name, category_name, date, latitude, longitude, description, source_id )
		@library_name = library_name
		@category_name = category_name
		@date = date
		@latitude = latitude
		@longitude = longitude
		@description = description
		@source_id = source_id
	end
	
	def save
		if @Id
			# update
		else
			# create
		end
	end
	
	def is_eq? record
		@library_name == record.library_name and
		@category_name == record.category_name and
		@date == record.date and
		@latitude == record.latitude and
		@longitude == record.longitude and
		@description == record.description and
		@source_id == record.source_id
	end
	
	def to_json
		{
		  latitude: @latitude,
		  longitude: @longitude,
		  occurred_on: @date.to_s,
		  description: @description,
		  category_name: @category_name,
		  source_id: @source_id
		}
	end
end

class FoodUKThunderBot
  attr_accessor :key
  
  def initialize( key = nil )
	if key.nil?
		@key = File.read('.key')
	else
		@key = key
	end
  end
  
  def read( xml )
	xml[ "EstablishmentCollection" ][ "EstablishmentDetail" ].each  do | e |

		a_date = e[ "RatingDate" ].split( '-' )
		date = DateTime.new( a_date[0].to_i, a_date[1].to_i, a_date[2].to_i )
		latitude = e[ "Geocode" ][ "Latitude" ]
		longitude = e[ "Geocode" ][ "Longitude" ]
		library_name = "Food UK - test"
		
		case e[ "RatingValue" ]
		when "awaitingpublication"
			category_name = "awaiting publication"
			description = e[ "BusinessName" ] + " is awaiting publication to be rate"
		when "awaitinginspection"
			category_name = "awaiting inspection"
			description = e[ "BusinessName" ] + " is awaiting inspection to be rate"
		when "exempt"
			category_name = "exempt"
			description = e[ "BusinessName" ] + " is exempt"
		else
			category_name = "noted"
			description = "Rating of " + e[ "BusinessName" ] + " is " + e[ "RatingValue" ]
		end
		
		source_id = "http://ratings.food.gov.uk/"
		
		publish( library_name, category_name, date, latitude, longitude, description, source_id )
		break
	end
	
  end
  
  def publish( library_name, category_name, date, latitude, longitude, description, source_id )
	api_call = "http://app.thundermaps.com/api/incident_reports/?library=#{library_name}&key=#{@key}"
	reports = [
			    {
			      latitude: latitude,
                  longitude: longitude,
			      occurred_on: date.to_s,
			      description: description,
			      category_name: category_name,
			      source_id: source_id
			    } ]
	pp reports
	HTTParty.post( api_call, 
		:body => { :reports => reports }.to_json,
		:headers => { 'Content-Type' => 'application/json' }
	)
	
	

  end
  
end
bot = FoodUKThunderBot.new
bot.read(  XmlSimple.xml_in( 'FHRS413en-GB.xml', { 'ForceArray' => false } ) )