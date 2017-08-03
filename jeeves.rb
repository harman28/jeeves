require 'json'
require 'logging'
require 'sinatra'
require 'httparty'
require 'wikipedia'
require 'washbullet'
require 'twilio-ruby'

logger = Logging.logger(STDOUT)
logger.level = :info

@env = settings.production? ? 'LIVE' : 'TEST'

logger.info "Booting in #{@env} mode"

Twilio.configure do |config|
  config.account_sid = ENV["TWILIO_#{@env}_SID"]
  config.auth_token  = ENV["TWILIO_#{@env}_TOKEN"]
end

helpers do
  def protected! route
    return if authorized? route
    headers['WWW-Authenticate'] = 'Basic realm="Restricted Area"'
    halt 401, "Not authorized\n"
  end

  def authorized? route
    @auth ||=  Rack::Auth::Basic::Request.new(request.env)
    valid_credentials = @auth.credentials == [route, ENV["#{route.upcase}_PASSWORD"]]
    @auth.provided? and @auth.basic? and @auth.credentials and valid_credentials
  end
end

get '/*' do
  "Jeeves is here, sir, and he's waiting for you.\n\n"\
  "More info: https://github.com/harman28/jeeves"
end

post '/twilio' do
  begin
    query = get_query params
    response = get_response query
    content_type 'text/xml'
  rescue => e
    logger.fatal e.message
    logger.fatal e.backtrace
    msg = "You has found bug! The app crashed. Please tell me this happened."
    response = build_twiml_response msg
  end
  response
end

post '/ola' do
  logger.info "Ola sent us this: #{params}"
end

post '/trace' do
  protected! 'trace'
  logger.info params.to_s
end

error do
  "Something quite terrible happened. Deets: " + ENV['sinatra.error'].message
end

def get_query params
  logger.info "Params: #{params.to_s}"
  @from = params['From']
  params['Body']
end

def get_response body
  cmd = body.split(' ').first.downcase
  if cmd == 'wiki'
    return get_wiki_response body
  elsif cmd == 'google'
    return get_google_response body
  elsif body.include? 'Twilio'
    return get_empty_response
  elsif pushable? body
    push_it body
    return get_empty_response
  else
    return get_save_response body
  end
end

def push_it body
  bullet = Washbullet::Client.new(ENV["PUSHBULLET_TOKEN"])
  bullet.push_note(
    receiver:   :device, # :email, :channel, :client
    identifier: ENV['PUSHBULLET_CHROME_ID'],
    params: {
      title: 'SMS',
      body:  body
    }
  )
end

def get_wiki_response query
  term = query[5..-1]
  page_number = /(?<page>(?<=page:)\d+)/.match(term)['page'].to_i rescue 1
  term = term.gsub(/page:\d+/, '')
  build_wiki_response Wikipedia.find(term), page_number
end

def get_google_response query
  query = query[7..-1]
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

def pushable? body
  is_otp = (body.include? "OTP" or body.downcase.include? "password")
  is_explicit_push = body.include? "push"
  is_otp or is_explicit_push
end

def get_save_response query
  body = "Jeeves: I don't know what to do with this. Try 'google {phrase}' or "\
  "'wiki {phrase}'? For everything else, eventually, I'll learn how to "\
  "just save it, but for now I'm just going to throw it away."

  build_twiml_response body
end

def get_empty_response
  build_twiml_response
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

def build_twiml_response body = nil
  logger.info "Body: #{body}"
  # body = nil if unrecognised_sender?
  twiml = Twilio::TwiML::Response.new do |r|
    r.Message body unless body.nil?
  end
  twiml.text
end

def unrecognised_sender?
  p @from
  p ENV['RECOGNISED_PHONE_NUMBER']
  @from != ENV['RECOGNISED_PHONE_NUMBER']
end
