require 'json'
require 'logging'
require 'sinatra'

require_relative 'jeeves/twilio'

@logger = Logging.logger(STDOUT)
@logger.level = :info

@env = settings.production? ? 'LIVE' : 'TEST'

@logger.info "Booting in #{@env} mode"

get '/*' do
  "Jeeves is here, sir, and he's waiting for you.\n\n"\
  "More info: https://github.com/harman28/jeeves"
end

post '/twilio' do
  return twilio_hook params
end
