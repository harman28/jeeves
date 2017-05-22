require 'json'
require 'logging'
require 'sinatra'
require 'httparty'
require 'wikipedia'
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
  "Jeeves is here, sir, and he's waiting for you.\n\n"\
  "More info: https://github.com/harman28/jeeves"
end

post '/twilio' do
  query = get_query params
  response = get_response query
  content_type 'text/xml'
  response
end

def get_query params
  logger.info "Params: #{params.to_s}"
  params['Body']
end

def get_response body
  case body.split(' ').first.downcase
  when 'wiki'
    return get_wiki_response body
  when 'google'
    return get_google_response body
  else
    return get_save_response body
  end
end

def get_wiki_response query
  term = query[5..-1]
  page_number = /(?<page>(?<=page:)\d+)/.match(term)['page'].to_i || 1
  term = term.gsub(/page:\d+/, '')
  build_wiki_response Wikipedia.find(term), page_number
end

def get_google_response query
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
  build_google_response JSON.parse(response.body)
end

def get_save_response query
  body = "Jeeves: I don't know what to do with this. Try 'google {phrase}' or "\
  "'wiki {phrase}'? For everything else, eventually, I'll learn how to "\
  "just save it, but for now I'm just going to throw it away."
  build_twiml_response body
end

def build_wiki_response page, page_number
  limit = 160*4
  start_index = (page_number-1)*limit
  end_index = start_index+limit
  string_response = page.text[start_index..end_index].gsub(/\s\w+\s*$/, '...')
  build_twiml_response string_response
end

def build_google_response result
  logger.debug "Result: #{result.to_s}"
  string_response = result['items'].inject([]) { |message,item|
    message.push(item['title'], item['snippet'])
  }.join("\n")
  build_twiml_response string_response
end

def build_twiml_response body
  logger.info "Body: #{body}"
  twiml = Twilio::TwiML::Response.new do |r|
    r.Message body
  end
  twiml.text
end
