nconf = require 'nconf'
{helpers} = require('habitrpg-shared')
user = require '../app/user.coffee'

module.exports.splash = (req, res, next) ->
  return next() # FIXME
  isStatic = req.url.split('/')[1] is 'static'
  unless req.query?.play? or req.session.userId or isStatic
    res.redirect('/static/front')
  else next()

module.exports.stagingUser = (req, res, next) ->
  return next() if req.is("json") # don't create new users / authenticate on REST calls

  if req.session.userId then next()
  else # New User - They get to play around before creating a new account.
    model = req.getModel()
    uobj = user.transformForDerby(helpers.newUser())
    req.session.userId = id = uobj.priv.id
    model.set '_session.userId', id
    model.add "usersPublic", uobj.pub, (err) ->
      return next(err) if err
      model.add "usersPrivate", uobj.priv, (err) ->
        return next(err) if err
        model.add "auths", {id, timestamps: created: +new Date}, next

module.exports.view = (req, res, next) ->
  model = req.getModel()
  model.set '_session.flags.isMobile', /Android|webOS|iPhone|iPad|iPod|BlackBerry/i.test(req.header 'User-Agent')
  model.set '_session.flags.nodeEnv', nconf.get('NODE_ENV')
  next()

#CORS middleware
module.exports.allowCrossDomain = (req, res, next) ->
  res.header "Access-Control-Allow-Origin", (req.headers.origin || "*")
  res.header "Access-Control-Allow-Methods", "OPTIONS,GET,POST,PUT,HEAD,DELETE"
  res.header "Access-Control-Allow-Headers", "Content-Type,Accept,Content-Encoding,X-Requested-With,x-api-user,x-api-key"

  # wtf is this for?
  if req.method is 'OPTIONS'
    res.send(200);
  else
    next()

module.exports.translate = (req, res, next) ->
  #model = req.getModel()

  # Set locale to bg on dev
  #model.set '_i18n.locale', 'bg' if nconf.get('NODE_ENV') is "development"

  next()