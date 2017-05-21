require 'sinatra'
require 'httparty'
require 'twilio-ruby'
require 'json'

@env = ENV['JEEVES_ENV'] == 'live' ? 'LIVE' : 'TEST'

Twilio.configure do |config|
  config.account_sid = ENV["TWILIO_#{@env}_SID"]
  config.auth_token  = ENV["TWILIO_#{@env}_TOKEN"]
end

@twilio_client = Twilio::REST::Client.new

post '/twilio' do
  query = get_query params
  result = get_result query
  response = build_response result
  content_type 'text/xml'
  response
end

def get_query params
  params['Body']
end

def get_result query
  response = HTTParty.get(
    "https://www.googleapis.com/customsearch/v1",
    query:
    {
      q: query,
      cx: ENV['GOOGLE_CSE_ID'],
      num: 2,
      key: ENV['GOOGLE_CSE_KEY']
    })
  JSON.parse(response.body)
end

def build_response result
  string_result = get_string_result result
  twiml = Twilio::TwiML::Response.new do |r|
    r.Message string_result
  end

  twiml.text
end

def get_string_result result
  result['items'].inject([]) { |message,item|
    message.push(item['title'],item['snippet'])
  }.join("\n")
end
