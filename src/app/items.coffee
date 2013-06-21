{items} = require 'habitrpg-shared'
_ = require 'lodash'
u = require './user.coffee'

###
  server exports
###
module.exports.server = (model) ->
  model.set '_page.items', items.items
  updateStore(model)

###
  app exports
###
module.exports.app = (app, model) ->
  user = u.userAts(model)

  app.fn 'buyItem', (e, el) ->
    [type, value, index] = [ $(el).attr('data-type'), $(el).attr('data-value'), $(el).attr('data-index') ]
    if changes = items.buyItem(user.pub.get(), type, value, index)
      _.each changes, (v,k) -> user.pub.set k,v; true
      updateStore(model)

module.exports.updateStore = updateStore = (model) ->
  nextItems = items.updateStore(model.get('_page.user.pub'))
  _.each nextItems, (v,k) -> model.set("_page.items.next.#{k}",v); true







