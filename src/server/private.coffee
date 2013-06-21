_ = require 'lodash'
u = require "../app/user.coffee"

module.exports.middleware = (req, res, next) ->
  nconf = require 'nconf'
  model = req.getModel()
  model.set '_session.stripePubKey', nconf.get('STRIPE_PUB_KEY')
  return next()

module.exports.app = (app, model) ->

  app.fn 'showStripe', (e, el) ->
    token = (res) ->
      $.ajax({
         type: "POST",
         url: "/charge",
         data: res
      }).success ->
        window.location.href = "/"
      .error (err) ->
        alert err.responseText

    disableAds = if (model.get('_session.user.flags.ads') is 'hide') then '' else 'Disable Ads, '

    StripeCheckout.open
      key: model.get('_session.stripePubKey')
      address: false
      amount: 500
      name: "Checkout"
      description: "Buy 20 Gems, #{disableAds}Support the Developers"
      panelLabel: "Checkout"
      token: token

  ###
    Buy Reroll Button
  ###
  app.fn 'buyReroll', ->
    ats = u.userAts(model)
    uobj = ats.priv.get()
    uobj.balance--
    _.each uobj.tasks, (task) ->
      task.value = 0 unless task.type is 'reward'
      true
    model.setDiff ats.priv.path(), uobj
  $('#reroll-modal').modal('hide')

module.exports.routes = (expressApp) ->
  nconf = require 'nconf'
  ###
    Setup Stripe response when posting payment
  ###
  expressApp.post '/charge', (req, res) ->
    stripeCallback = (err, response) ->
      if err
        console.error(err, 'Stripe Error')
        return res.send(500, err.response.error.message)
      else
        model = req.getModel()
        userId = model.get('_session.userId') #or model.session.userId # see http://goo.gl/TPYIt
        req._isServer = true
        model.fetch "users.#{userId}", (err, user) ->
          model.ref '_session.user', "users.#{userId}"
          model.set('_session.user.balance', model.get('_session.user.balance')+5)
          model.set('_session.user.flags.ads','hide')
          return res.send(200)

    api_key = nconf.get('STRIPE_API_KEY') # secret stripe API key
    stripe = require("stripe")(api_key)
    token = req.body.id
    # console.dir {token:token, req:req}, 'stripe'
    stripe.charges.create
      amount: "500" # $5
      currency: "usd"
      card: token
    , stripeCallback