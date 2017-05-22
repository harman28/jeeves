require 'json'
require 'logging'
require 'sinatra'
require 'httparty'
require 'twilio-ruby'

logger = Logging.logger(STDOUT)
logger.level = :info

@env = settings.production? ? 'LIVE' : 'TEST'

logger.info "Booting in #{@env} mode"

Twilio.configure do |config|
  config.account_sid = ENV["TWILIO_#{@env}_SID"]
  config.auth_token  = ENV["TWILIO_#{@env}_TOKEN"]
end

get '/*' do
  "Jeeves is here, sir, and he's waiting for you."
end

post '/twilio' do
  query = get_query params
  result = get_result query
  response = build_response result
  content_type 'text/xml'
  response
end

def get_query params
  logger.info "Params: #{params.to_s}"
  params['Body']
end

def get_result query
  logger.info "Query: #{query}"
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
  logger.debug "Result: #{result.to_s}"
  string_result = get_string_result result
  twiml = Twilio::TwiML::Response.new do |r|
    r.Message string_result
  end
  logger.info "Result: #{string_result}"
  twiml.text
end

def get_string_result result
  result['items'].inject([]) { |message,item|
    message.push(item['title'],item['snippet'])
  }.join("\n")
end
