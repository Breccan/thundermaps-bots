require 'pp'
require 'json'
require 'httparty'
require 'xmlsimple'
require 'net/http'
require 'date'
require 'logger'

LOG_FILE = "bot.log"

class Record
  attr_accessor :account_name, :category_name, :occurred_on, :latitude, :longitude, :description, :source_id, :ID

  def initialize( account_name, category_name, occurred_on, latitude, longitude, description, source_id )
    @account_name = account_name
    @category_name = category_name
    @occurred_on = occurred_on
    @latitude = latitude
    @longitude = longitude
    @description = description
    @source_id = source_id
  end

  def escape S
    s.gsub(/\\/, '\&\&').gsub(/'/, "''").gsub(/"/, '""')
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
    account_name = "food-uk-test"

    begin
      a_date = e[ "RatingDate" ].split( '-' )
      occurred_on = DateTime.new( a_date[0].to_i, a_date[1].to_i, a_date[2].to_i )
    rescue
      occurred_on = DateTime.now
    end
    business_name = e[ "BusinessName" ]
    case e[ "RatingValue" ].downcase
    when "awaitingpublication"
      category_name = "awaiting publication"
      description = business_name + " is awaiting publication to be rated"
    when "awaitinginspection"
      category_name = "awaiting inspection"
      description = business_name + " is awaiting inspection to be rated"
    when "exempt"
      category_name = "exempt"
      description = business_name + " is exempt"
    else
      category_name = "noted"
      description = "In the local authority of " + e["LocalAuthorityName"] + " the " + e[ "BusinessType" ] + " called " + e[ "BusinessName" ] +
        "received the following scores: Hygiene: " + e["Hygiene"] + ", Structural: " + e["Structural"] + ", Confidence in management "
      + e [ "ConfidenceInManagement" ] + ". To find out more see: http://ratings.food.gov.uk/"
    end

    source_id = e["FHRSID"]

    publish( Record.new( account_name, category_name, occurred_on, latitude, longitude, description, source_id ) )
    break if index == 3
    end

  end

  def publish( record )
    api_call = "http://app.thundermaps.com/api/incident_reports/?account=#{record.account_name}&key=#{@key}"
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
end
