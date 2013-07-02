{items} = require 'habitrpg-shared'
_ = require 'lodash'

module.exports.updateStore = updateStore = (model) ->
  nextItems = items.updateStore(model.get('_page.user.pub'))
  _.each nextItems, (v,k) -> model.set("_page.items.next.#{k}",v); true

###
  server exports
###
module.exports.server = (model) ->
  model.set '_page.items', items.items
  updateStore(model)

###
  app exports
###
module.exports.app = (app) ->
  app.fn
    items:
      buy: (e, el) ->
        [type, value, index] = [ $(el).attr('data-type'), $(el).attr('data-value'), $(el).attr('data-index') ]
        if changes = items.buyItem(@pub.get(), type, value, index)
          _.each changes, (v,k) => @pub.set k,v; true
          updateStore(@model)
      updateStore: ->
        updateStore @model









