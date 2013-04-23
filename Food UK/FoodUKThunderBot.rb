require 'pp'
require 'json'
require 'httparty'
require 'xmlsimple'
require 'sqlite3'
require 'net/http'
require 'date'
require 'logger'

DATABASE_NAME = "history.db"
LOG_FILE = "bot.log"

class Record
	attr_accessor :library_name, :category_name, :occurred_on, :latitude, :longitude, :description, :source_id, :ID
	
	@@db = nil
	
	TABLE_NAME = "Records"
	
	def self.set_db db
		@@db = db
	end
	
	def initialize( library_name, category_name, occurred_on, latitude, longitude, description, source_id )
		@library_name = library_name
		@category_name = category_name
		@occurred_on = occurred_on
		@latitude = latitude
		@longitude = longitude
		@description = description
		@source_id = source_id
		
		sync_with_history
	end
	
	def sync_with_history
		stm = @@db.prepare "SELECT ID FROM #{TABLE_NAME} WHERE library_name = :library_name AND category_name= :category_name AND occurred_on= :occurred_on AND latitude= :latitude AND longitude= :longitude AND description=:description AND source_id= :source_id"
		stm.bind_param "library_name", @library_name
		stm.bind_param "category_name", @category_name
		stm.bind_param "occurred_on", @occurred_on.to_s
		stm.bind_param "latitude", @latitude
		stm.bind_param "longitude", @longitude
		stm.bind_param "description", @description
		stm.bind_param "source_id", @source_id
		rs = stm.execute

		row = rs.next
		
		if row
			MyLogger.logger.info 'already broadcasted'
			@ID = row["ID"]
		else
			MyLogger.logger.info 'looks as new record'
			@ID = nil
		end
		stm.close
	end
	
	def is_not_exist_in_history?
		@ID.nil?
	end
	
	def save
		if is_not_exist_in_history?
			# create
			@@db.execute "INSERT INTO #{TABLE_NAME} ( ID, library_name, category_name, occurred_on, latitude, longitude, description, source_id ) VALUES( (SELECT max(ID) FROM #{TABLE_NAME})+1, '#{@library_name}', '#{@category_name}', '#{@occurred_on}', '#{@latitude}', '#{@longitude}', '#{@description}', '#{@source_id}' )"
			@ID = @@db.last_insert_row_id
		else
			# update
			MyLogger.logger.warn 'no make sense to update'
		end
	end
	
	def to_json
		{
		  latitude: @latitude,
		  longitude: @longitude,
		  occurred_on: @occurred_on.to_s,
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
	xml[ "EstablishmentCollection" ][ "EstablishmentDetail" ].each_with_index  do | e, index |

		
		latitude = e[ "Geocode" ][ "Latitude" ]
		longitude = e[ "Geocode" ][ "Longitude" ]
		#library_name = "food-uk-test"
		library_name = "test"
		
		begin
			a_date = e[ "RatingDate" ].split( '-' )
			occurred_on = DateTime.new( a_date[0].to_i, a_date[1].to_i, a_date[2].to_i )
		rescue
			occurred_on = DateTime.now
		end
		
		case e[ "RatingValue" ].downcase
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
		
		publish( Record.new( library_name, category_name, occurred_on, latitude, longitude, description, source_id ) )
		break if index == 3
	end
	
  end
  
  def publish( record )
	if record.is_not_exist_in_history?
		api_call = "http://app.thundermaps.com/api/incident_reports/?library=#{record.library_name}&key=#{@key}"
		reports = [
					{
					  latitude: record.latitude,
					  longitude: record.longitude,
					  occurred_on: record.occurred_on.to_s,
					  description: record.description,
					  category_name: record.category_name,
					  source_id: record.source_id
					} ]
		MyLogger.logger.info reports.inspect
		MyLogger.logger.info HTTParty.post( api_call, 
			:body => { :reports => reports }.to_json,
			:headers => { 'Content-Type' => 'application/json' }
		).inspect
		
		record.save
	end
  end
  
end

class MyLogger
	@@logger = nil
	
	def self.set_logger logger
		@@logger = logger
	end
	
	def self.logger
		@@logger
	end
end

begin
	MyLogger.set_logger Logger.new( LOG_FILE, 'daily' )
	db = SQLite3::Database.open DATABASE_NAME
	db.results_as_hash = true
	Record.set_db db
	bot = FoodUKThunderBot.new
	
	json_url = 'http://data.gov.uk/api/2/rest/package/uk-food-hygiene-rating-data-yorkshire-and-humberside-food-standards-agency'
	MyLogger.logger.info 'getting catalog...'
	MyLogger.logger.info 'from ' + json_url
	uri = URI( json_url )
	json = Net::HTTP.get(uri)
	parsed = JSON.parse( json ) # returns a hash
	parsed['resources'].each do | resource |
		if resource[ 'url' ] and resource[ 'description' ]
			uri = URI( resource[ 'url' ] )
			MyLogger.logger.info 'getting ' + resource[ 'description' ] + '...'
			xml = Net::HTTP.get(uri)
			bot.read(  XmlSimple.xml_in(xml , { 'ForceArray' => false } ) )
		end
	end
rescue SQLite3::Exception => e 
	MyLogger.logger.fatal "Exception occured with DATABASE #{DATABASE_NAME}"
	MyLogger.logger.fatal
ensure
	#db.close if db
end
