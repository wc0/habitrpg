{helpers, algos, items} = require 'habitrpg-shared'
browser = require './browser.coffee'
misc = require './misc.coffee'
_ = require 'lodash'

module.exports.app = (app, model) ->
  user = model.at('_session.user')

  app.fn 'revive', ->
    # Reset stats
    user.set 'stats.hp', 50
    user.set 'stats.exp', 0
    user.set 'stats.gp', 0
    user.incr 'stats.lvl', -1 if user.get('stats.lvl') > 1

    ## Lose a random item
    loseThisItem = false
    owned = user.get('items')
    # unless they're already at 0-everything
    if parseInt(owned.armor)>0 or parseInt(owned.head)>0 or parseInt(owned.shield)>0 or parseInt(owned.weapon)>0
      # find a random item to lose
      until loseThisItem
        #candidate = {0:'items.armor', 1:'items.head', 2:'items.shield', 3:'items.weapon', 4:'stats.gp'}[Math.random()*5|0]
        candidate = {0:'armor', 1:'head', 2:'shield', 3:'weapon'}[Math.random()*4|0]
        loseThisItem = candidate if owned[candidate] > 0
      user.set "items.#{loseThisItem}", 0

    items.updateStore(model)

  app.fn 'reset', (e, el) ->
    misc.batchTxn model, (uObj, paths, batch) ->
      batch.set 'tasks', {}
      ['habit', 'daily', 'todo', 'reward'].forEach (type) -> batch.set("ids.#{type}s", [])
      _.each {hp:50, lvl:1, gp:0, exp:0}, (v,k) -> batch.set("stats.#{k}",v)
      _.each {armor:0, weapon:0, head:0, shield:0}, (v,k) -> batch.set("items.#{k}",v)
    items.updateStore(model)
    browser.resetDom(model)

  app.fn 'closeNewStuff', (e, el) ->
    user.set('flags.newStuff', 'hide')

  app.fn 'customizeGender', (e, el) ->
    user.set 'preferences.gender', $(el).attr('data-value')

  app.fn 'customizeHair', (e, el) ->
    user.set 'preferences.hair', $(el).attr('data-value')

  app.fn 'customizeSkin', (e, el) ->
    user.set 'preferences.skin', $(el).attr('data-value')

  app.fn 'customizeArmorSet', (e, el) ->
    user.set 'preferences.armorSet', $(el).attr('data-value')

  app.fn 'restoreSave', ->
    misc.batchTxn model, (uObj, paths, batch) ->
      $('#restore-form input').each ->
        [path, val] = [$(this).attr('data-for'), parseInt($(this).val() || 1)]
        batch.set(path,val)

  app.fn 'toggleHeader', (e, el) ->
    user.set 'preferences.hideHeader', !user.get('preferences.hideHeader')

  app.fn 'deleteAccount', (e, el) ->
    model.del "users.#{user.get('id')}", ->
      location.href = "/logout"

  app.fn 'profileAddWebsite', (e, el) ->
    newWebsite = model.get('_page.new.profileWebsite')
    return if /^(\s)*$/.test(newWebsite)
    user.unshift 'profile.websites', newWebsite
    model.set '_page.new.profileWebsite', ''

  app.fn 'profileRemoveWebsite', (e, el) ->
    sites = user.get 'profile.websites'
    i = sites.indexOf $(el).attr('data-website')
    sites.splice(i,1)
    user.set 'profile.websites', sites


  toggleGamePane = ->
    model.set '_page.active.gamePane', !model.get('_page.active.gamePane'), ->
      browser.setupTooltips()

  app.fn 'clickAvatar', (e, el) ->
    uid = $(el).attr('data-uid')
    if uid is model.get('_session.userId') # clicked self
      toggleGamePane()
    else
      $("#avatar-modal-#{uid}").modal('show')

  app.fn 'toggleGamePane', -> toggleGamePane()

  app.fn 'toggleResting', ->
    model.set '_session.user.flags.rest', !model.get('_session.user.flags.rest')

