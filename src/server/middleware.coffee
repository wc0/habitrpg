splash = (req, res, next) ->
  isStatic = req.url.split('/')[1] is 'static'
  unless req.query?.play? or req.getModel().get('_session.userId') or isStatic
    res.redirect('/static/front')
  else
    next()

view = (req, res, next) ->
  model = req.getModel()
  model.set '_session.flags.isMobile', /Android|webOS|iPhone|iPad|iPod|BlackBerry/i.test(req.header 'User-Agent')
  model.set '_session.flags.nodeEnv', process.env.NODE_ENV
  next()

#CORS middleware
allowCrossDomain = (req, res, next) ->
  res.header "Access-Control-Allow-Origin", (req.headers.origin || "*")
  res.header "Access-Control-Allow-Methods", "OPTIONS,GET,POST,PUT,HEAD,DELETE"
  res.header "Access-Control-Allow-Headers", "Content-Type,Accept,Content-Encoding,X-Requested-With,x-api-user,x-api-key"

  # wtf is this for?
  if req.method is 'OPTIONS'
    res.send(200);
  else
    next()

translate = (req, res, next) ->
  model = req.getModel()

  # Set locale to bg on dev
  #model.set '_i18n.locale', 'bg' if process.env.NODE_ENV is "development"

  next()

module.exports = { splash, view, allowCrossDomain, translate}