{items} = require 'habitrpg-shared'
_ = require 'lodash'

###
  server exports
###
module.exports.server = (model) ->
  model.set '_page.items', items.items
  updateStore(model)

###
  app exports
###
module.exports.app = (appExports, model) ->
  user = model.at '_session.user'

  appExports.buyItem = (e, el) ->
    [type, value, index] = [ $(el).attr('data-type'), $(el).attr('data-value'), $(el).attr('data-index') ]
    if changes = items.buyItem(user.get(), type, value, index)
      _.each changes, (v,k) -> user.set k,v; true
      updateStore(model)

module.exports.updateStore = updateStore = (model) ->
  nextItems = items.updateStore(model.get('_session.user'))
  _.each nextItems, (v,k) -> model.set("_page.items.next.#{k}",v); true







