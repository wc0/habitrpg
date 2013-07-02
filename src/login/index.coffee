app = require('derby').createApp module
app
  .use(require('derby-ui-boot'))
  .use(require('../../ui'))
  .use(require 'derby-auth/components/index.coffee')

# ========== ROUTES ==========

app.get '/home', (page, model, params, next) ->
  page.render('login')

# ========== CONTROLLER FUNCTIONS ==========

app.ready (model) ->