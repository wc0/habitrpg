express = require('express')
derby = require('derby')
racerBrowserChannel = require('racer-browserchannel')
LiveDbMongo = require('livedb-mongo').LiveDbMongo
MongoStore = require('connect-mongo')(express)
app = require('../app')
error = require('./error')
#mongoskin = require('mongoskin')

auth = require 'derby-auth'
priv = require './private'
habitrpgStore = require './store'
middleware = require './middleware'
helpers = require("habitrpg-shared/script/helpers")

# Infinite stack trace
Error.stackTraceLimit = Infinity if process.env.NODE_ENV is 'development'

# Set up our express app

expressApp = module.exports = express()

# Get Redis configuration
if process.env.REDIS_HOST
  redis = require("redis").createClient(process.env.REDIS_PORT, process.env.REDIS_HOST)
  redis.auth process.env.REDIS_PASSWORD
else if process.env.REDISCLOUD_URL
  redisUrl = require("url").parse(process.env.REDISCLOUD_URL)
  redis = require("redis").createClient(redisUrl.port, redisUrl.hostname)
  redis.auth redisUrl.auth.split(":")[1]
else
  redis = require("redis").createClient()
redis.select process.env.REDIS_DB or 7

# Get Mongo configuration
mongoUrl = process.env.NODE_DB_URI or "mongodb://localhost:27017/habitrpg"
#mongo = mongoskin.db(mongoUrl + "?auto_reconnect",
#  safe: true
#)

# The store creates models and syncs data
store = derby.createStore(
  db: new LiveDbMongo(mongo)
  redis: redis
)

# Authentication setup
strategies =
  facebook:
    strategy: require("passport-facebook").Strategy
    conf:
      clientID: process.env.FACEBOOK_KEY
      clientSecret: process.env.FACEBOOK_SECRET
options =
  domain: process.env.BASE_URL || 'http://localhost:3000'
  allowPurl: true
  schema: helpers.newUser(true)

# This has to happen before our middleware stuff
auth.store(store, habitrpgStore.customAccessControl)

expressApp
  .use(middleware.allowCrossDomain)
  .use(express.favicon()) # Gzip dynamically
  .use(express.compress()) # Respond to requests for application script bundles
  .use(app.scripts(store)) # Serve static files from the public directory
  .use(express['static'](__dirname + "/../../public"))

# Session middleware
  .use(express.cookieParser())
  .use(express.session(
    secret: process.env.SESSION_SECRET or "YOUR SECRET HERE"
    store: new MongoStore(
      url: mongoUrl
      safe: true
    )
  ))

#.use(everyauth.middleware(autoSetupRoutes: false))

# Add browserchannel client-side scripts to model bundles created by store,
# and return middleware for responding to remote client messages
  .use(racerBrowserChannel(store))
# Add req.getModel() method
  .use(store.modelMiddleware())

# Custom Translations
  .use(middleware.translate)

# API should be hit before all other routes
  .use('/api/v1', require('./api').middleware)
  .use('/api/v2', require('./apiv2').middleware)
  .use(require('./deprecated').middleware)

# Other custom middlewares
  .use(middleware.splash) # Show splash page for newcomers
  .use(priv.middleware)
  .use(middleware.view)
  .use(auth.middleware(strategies, options))

# Parse form data
  .use(express.bodyParser())
  .use(express.methodOverride())

#.use(rememberUser)

# Create an express middleware from the app's routes
  .use(app.router())
  .use(require('./static').middleware) #custom static middleware
  .use error()

priv.routes(expressApp)

# SERVER-SIDE ROUTES #

expressApp.all "*", (req, res, next) ->
  next "404: " + req.url