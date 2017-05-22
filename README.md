# Jeeves
Sinatra app that responds to requests sent via SMS

![CC0 Public Domain](butler.jpg?raw=true "Jeeves")

### Setup
Jeeves is essentially just a webhook for Twilio to hit at the moment.

[Twilio](twilio.com) is a SMS service provider that gives you a free number, that you can then use to send and receive SMSes. Set your incoming SMS webhook to the `/twilio` route wherever you're hosting your server.

Send your search query from a registered number to your Twilio number, and you should get a response.

Expects the following vars to be set
 - `TWILIO_LIVE_SID`: From Twilio dashboard
 - `TWILIO_LIVE_TOKEN`: From Twilio dashboard
 - `GOOGLE_CSE_ID`: ID of your Custom Search Engine
 - `GOOGLE_CSE_KEY`: Key to use the CSE API

### TODO
 - Handle errors everywhere
 - - Error handling for Twilio
 - - Auth errors on CSE
 - Validate request source using [this](https://www.twilio.com/docs/api/security)
 - Dynamic query/summary logic based on SMS body
 - - ~~"wiki {term}" should give just the wikipedia content~~
 - - "wiki disambig {term}" should help figure out the term
 - - ~~"google {term}" should return search result~~
 - - "okay google {term}" should give intelligent responses
 - - Save everything else, somehow
 - SMSes can be just one thing Jeeves does. Make me a full time valet. Branch: `jeeves_is_a_valet_not_a_mailmain`
 - Add tests
