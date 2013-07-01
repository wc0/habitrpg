{helpers, algos, items} = require 'habitrpg-shared'
browser = require './browser.coffee'
u = require './user.coffee'
_ = require 'lodash'

module.exports.app = (app, model) ->
  user = u.userAts(model)

  app.fn 'revive', ->
    uobj = user.pub.get()
    _.each {hp:50, gp:0, exp:0}, (v,k) -> user.pub.set "stats.#{k}", v; true
    user.pub.set('stats.lvl', --uobj.stats.lvl) if uobj.stats.lvl > 1

    ## Lose a random item
    loseThisItem = false
    owned = uobj.items
    # unless they're already at 0-everything
    if +owned.armor > 0 or +owned.head > 0 or +owned.shield > 0 or +owned.weapon > 0
      # find a random item to lose
      until loseThisItem
        #candidate = {0:'items.armor', 1:'items.head', 2:'items.shield', 3:'items.weapon', 4:'stats.gp'}[Math.random()*5|0]
        candidate = {0:'armor', 1:'head', 2:'shield', 3:'weapon'}[Math.random()*4|0]
        loseThisItem = candidate if owned[candidate] > 0
      user.pub.set "items.#{lostThisItem}", 0

    items.updateStore(model)

  app.fn 'reset', (e, el) ->
    user.priv.set 'tasks', {}
    ['habit', 'daily', 'todo', 'reward'].forEach (type) -> user.priv.set "ids.#{type}s", []

    _.each {hp:50, lvl:1, gp:0, exp:0}, (v,k) -> user.pub.set "stats.#{k}", v; true
    _.each {armor:0, weapon:0, head:0, shield:0}, (v,k) -> user.pub.set "items.#{k}", v; true

    items.updateStore(model)
    #browser.resetDom(model)

  app.fn 'closeNewStuff', (e, el) ->
    user.priv.set('flags.newStuff', 'hide')

  app.fn 'customizeAvatar', (e, el) ->
    [k, v] = [$(el).attr('data-attr'), $(el).attr('data-value')]
    user.pub.set "preferences.#{k}", v

  app.fn 'restoreSave', ->
    $('#restore-form input').each ->
      [path, val] = [$(this).attr('data-for'), +$(this).val() || 1]
      user.pub.set(path,val)

  app.fn 'toggleHeader', (e, el) ->
    user.pub.set 'preferences.hideHeader', !user.pub.get('preferences.hideHeader')

  app.fn 'deleteAccount', (e, el) ->
    count = 3
    done = ->
      location.href = "/logout" if (--count is 0)
    ['usersPublic', 'usersPrivate', 'auths'].forEach (collection) ->
      model.del "#{collection}.#{user.id}", done

  app.fn 'profileAddWebsite', (e, el) ->
    newWebsite = model.get('_page.new.profileWebsite')
    return if /^(\s)*$/.test(newWebsite)
    user.pub.unshift 'profile.websites', newWebsite
    model.set '_page.new.profileWebsite', ''

  app.fn 'profileRemoveWebsite', (e, el) ->
    sites = user.pub.get 'profile.websites'
    i = sites.indexOf $(el).attr('data-website')
    sites.splice(i,1)
    user.pub.set 'profile.websites', sites


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
    user.priv.set 'flags.rest', !user.priv.get('flags.rest')

