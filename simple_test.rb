require 'pp'
require 'json'
require 'httparty'

key = '-- YOUR KEY --'

library_name = 'test'
category_name = 'tasty'

api_call = "http://app.thundermaps.com/api/incident_reports/?library=#{library_name}&key=#{key}"

date = Date.today

wellington = { latitude:-41.284901, longitude: 174.776344 }

description = 'hello from simple test'

source_id = 'source_id'

pp HTTParty.post( api_call, 
    :body => { :reports => [
			    {
			      latitude: wellington[ :latitude ],
                  longitude: wellington[ :longitude ],
			      occurred_on: date.to_s,
			      description: description,
			      category_name: category_name,
			      source_id: source_id
			    } ]
             }.to_json,
    :headers => { 'Content-Type' => 'application/json' } )
