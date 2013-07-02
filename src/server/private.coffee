_ = require 'lodash'

module.exports.middleware = (req, res, next) ->
  nconf = require 'nconf'
  model = req.getModel()
  model.set '_session.stripePubKey', nconf.get('STRIPE_PUB_KEY')
  return next()

module.exports.app = (app, model) ->
  u = require '../app/user.coffee'

  app.fn

    ###
      Show Stripe
    ###
    showStripe: (e, el) ->
      token = (res) ->
        $.ajax({
           type: "POST",
           url: "/charge",
           data: res
        }).success ->
          window.location.href = "/"
        .error (err) ->
          alert err.responseText

      disableAds = unless (@priv.get('flags.ads') is 'hide') then '' else 'Disable Ads, '

      StripeCheckout.open
        key: model.get('_session.stripePubKey')
        address: false
        amount: 500
        name: "Checkout"
        description: "Buy 20 Gems, #{disableAds}Support the Developers"
        panelLabel: "Checkout"
        token: token

    ###
      Buy Reroll
    ###
    buyReroll: ->
      priv = @priv.get()
      paths = {}
      priv.balance--; paths.balance = true
      _.each priv.tasks, (task) ->
        unless task.type is 'reward'
          task.value = 0; (paths.tasks ?= {})[task.id] = true;
        true
      u.setDiff @model, {pub:@pub.get(), priv}, paths, {cb: ->app.browser.resetDom()}
      $('#reroll-modal').modal('hide')


module.exports.routes = (expressApp) ->
  nconf = require 'nconf'

  ###
    Setup Stripe response when posting payment
  ###
  expressApp.post '/charge', (req, res, next) ->
    stripe = require("stripe")(nconf.get('STRIPE_API_KEY'))
    token = req.body.id
    # console.dir {token:token, req:req}, 'stripe'
    stripe.charges.create
      amount: "500" # $5
      currency: "usd"
      card: token
    , (err, response) ->
        if err
          console.error(err, 'Stripe Error')
          return res.send(500, err.response.error.message)
        model = req.getModel()
        uid = model.get('_session.userId') #or model.session.userId # see http://goo.gl/TPYIt
        $priv = model.at "usersPrivate.#{uid}"
        $priv.fetch (err) ->
          return next err if err
          $priv.set "flags.ads", 'hide', ->
            $priv.increment "balance", 5, ->
              return res.send(200)