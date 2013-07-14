_ = require 'lodash'
{algos, helpers} = require 'habitrpg-shared'
async = require 'async'

properties =
  pub: [
    'id',
    'achievements',
    'backer',       # locked
    'invitations',  # writeable
    'items',
    'preferences',
    'profile',
    'stats',
    'challenges'
  ]
  priv: [
    'id',
    'apiToken',
    'balance',      #locked
    'ids',
    'filters',
    'flags',
    'history',
    'lastCron',
    'party',
    'tags',
    'tasks'
  ]

###
Transform the schema provided by API or Helpers into something Derby can use (depends on public, private, and auth collections)
###
module.exports.transformForDerby = transformForDerby = (user) ->
  obj =
    pub: id: user.id
    priv: id: user.id
  _.each user, (v,k) ->
    if k in properties.pub then obj.pub[k] = v
    else if k in properties.priv then obj.priv[k] = v
    true
  toObj = (arr) -> _.object _.pluck(arr, 'id'), arr
  obj.priv.tasks = toObj (user.habits ? []).concat(user.dailys ? []).concat(user.todos ? []).concat(user.rewards ? [])
  obj.priv.ids =
    habits: _.pluck user.habits, 'id'
    dailys: _.pluck user.dailys, 'id'
    todos: _.pluck user.todos, 'id'
    rewards: _.pluck user.rewards, 'id'
  obj

###
Transform the schema provided by Derby so it can be consumed by API / Helpers
###
module.exports.transformForAPI = transformForAPI = (pub, priv) ->
  merged = {}
  _.merge merged, pub, priv
  _.each ['habit','daily','todo','reward'], (type) ->
    # FIXME sorting
    merged["#{type}s"] = _.filter(merged.tasks, {type}); true

  # TODO remove this?
  # I think let's not do this for now. It will cause overhead for API (we're sending user[type]s*4 + user.tasks);
  # however, when I run cron, since user.tasks still holds var references, theyr'e updated and I don't have to map back
  # in a complex way
  #delete merged.ids
  #delete merged.tasks
  merged

###
Small helper for getting user references from the various referenced collections
###
module.exports.userAts = (model) ->
  {
    pub: model.at("_page.user.pub")
    priv: model.at("_page.user.priv")
    id: model.get('_session.userId')
  }

###
  model.setDiff() is extremely expensive, especially if your object has arrays in it. I mean "often crashes chrome"
  expensive. So here we add our own custom diff requiring a `paths` object to tell where to set
###
module.exports.setDiff = setDiff = (model, obj, paths, options={}) ->
  _.defaults options, {pass:{}, cb:->}

  unless obj.pub and obj.priv
    obj = module.exports.transformForDerby obj

  # Allows us to still run a post-set callback, even though we're performing many sets
  count = _.size paths
  done = -> options.cb() if (--count is 0)

  ats = module.exports.userAts model
  _.each paths, (v, path) ->
    parent = path.split('.')[0]
    privacy = if parent in properties.priv then 'priv' else if parent in properties.pub then 'pub'
    ats[privacy].pass(options.pass).set path, helpers.dotGet(path, obj[privacy]), done
    true


###
  ------------------------------------------------------------------------------
  Preening Functions
  ------------------------------------------------------------------------------
###


###
Preen history for users with > 7 history entries
This takes an infinite array of single day entries [day day day day day...], and turns it into a condensed array
of averages, condensing more the further back in time we go. Eg, 7 entries each for last 7 days; 4 entries for last
4 weeks; 12 entries for last 12 months; 1 entry per year before that: [day*7 week*4 month*12 year*infinite]
###
preenItemHistory = (history) ->
  history = _.filter history, ((h) -> !!h) # discard nulls (corrupted somehow)
  preen = (amount, groupBy) ->
    groups = undefined
    avg = undefined
    start = undefined

    groups = _(history)
      .groupBy((h) -> moment(h.date).format groupBy) # get date groupings to average against
      .sortBy((h, k) -> k) # sort by date
      .value() # turn into an array
    amount++ # if we want the last 4 weeks, we're going 4 weeks back excluding this week. so +1 to account for exclusion
    start = (if (groups.length - amount > 0) then groups.length - amount else 0)
    groups = groups.slice(start, groups.length - 1)
    _.each groups, (group) ->
      avg = _.reduce(group, (mem, obj) ->
        mem + obj.value
      , 0) / group.length
      newHistory.push
        date: +moment(group[0].date)
        value: avg

  newHistory = []
  preen 50, "YYYY" # last 50 years
  preen 12, "YYYYMM" # last 12 months
  preen 4, "YYYYww" # last 4 weeks
  newHistory = newHistory.concat(history.slice(-7)) # last 7 days
  newHistory

minHistLen = 7
module.exports.preenUserHistory = preenUserHistory = (uobj, options) ->
  paths = options?.paths or {}

  _.each uobj.tasks, (task) ->
    if task.history?.length > minHistLen
      task.history = preenItemHistory(task.history)
      paths["tasks.#{task.id}.history"] = true

  if uobj.history?.exp?.length > minHistLen
    uobj.history.exp = preenItemHistory(uobj.history.exp)
    paths['history.exp'] = true
  if uobj.history?.todos?.length > minHistLen
    uobj.history.todos = preenItemHistory(uobj.history.todos)
    paths['history.todos'] = true


###
  Expose app functions
###
module.exports.app = (app) ->
  app.fn
    user:

      ###
        Cron
      ###
      cron: ->
        async.nextTick =>
          uobj = transformForAPI @pub.get(), @priv.get()
          paths = {}
          algos.cron uobj, {paths}
          preenUserHistory uobj, {paths}
          if _.size(paths) > 0
            if (delete paths['stats.hp'])? # we'll set this manually so we can get a cool animation
              hp = uobj.stats.hp
              setTimeout =>
                # we need to reset dom - too many changes have been made and won't it breaks dom listeners.
                #browser.resetDom(model)
                @pub.set 'stats.hp', hp
              , 500
            setDiff @model, uobj, paths, {pass: cron: true}
            #_.each paths, (v,k) -> user.pass({cron:true}).set(k,helpers.dotGet(k, uObj));true

      ###
        Revive
      ###
      revive: ->
        uobj = @pub.get()
        _.each {hp:50, gp:0, exp:0}, (v,k) => @pub.set "stats.#{k}", v; true
        @pub.set('stats.lvl', --uobj.stats.lvl) if uobj.stats.lvl > 1

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
          @pub.set "items.#{loseThisItem}", 0

        app.items.updateStore()

      ###
        Reset
      ###
      reset: (e, el) ->
        @priv.set 'tasks', {}
        ['habit', 'daily', 'todo', 'reward'].forEach (type) => @priv.set "ids.#{type}s", []

        _.each {hp:50, lvl:1, gp:0, exp:0}, (v,k) => @pub.set "stats.#{k}", v; true
        _.each {armor:0, weapon:0, head:0, shield:0}, (v,k) => @pub.set "items.#{k}", v; true

        app.items.updateStore()
        #browser.resetDom(model)

      ###
        Close New Stuff
      ###
      closeNewStuff: (e, el) ->
        @priv.set('flags.newStuff', 'hide')

      ###
        Customize Avatar
      ###
      customizeAvatar: (e, el) ->
        [k, v] = [$(el).attr('data-attr'), $(el).attr('data-value')]
        @pub.set "preferences.#{k}", v

      ###
        Restore Save
      ###
      restoreSave: ->
        pub = @pub
        $('#restore-form input').each ->
          [path, val] = [$(this).attr('data-for'), +($(this).val() or 1)]
          pub.set(path,val)

      ###
        Toggle Header
      ###
      toggleHeader: (e, el) ->
        @pub.set 'preferences.hideHeader', !@pub.get('preferences.hideHeader')

      ###
        Delete Account
      ###
      deleteAccount: (e, el) ->
        count = 3
        done = ->
          location.href = "/logout" if (--count is 0)
        ['usersPublic', 'usersPrivate', 'auths'].forEach (collection) =>
          @model.del "#{collection}.#{@uid}", done

      ###
        Add Website
      ###
      addWebsite: (e, el) ->
        newWebsite = @model.get('_page.new.profileWebsite')
        return if /^(\s)*$/.test(newWebsite)
        @pub.unshift 'profile.websites', newWebsite
        @model.set '_page.new.profileWebsite', ''

      ###
        Toggle Game Pane
      ###
      toggleGamePane: ->
        @model.set '_page.active.gamePane', !@model.get('_page.active.gamePane'), ->
          app.browser.setupTooltips()

      ###
        Click Avatar
      ###
      clickAvatar: (e, el) ->
        uid = $(el).attr('data-uid')
        if uid is @uid then app.user.toggleGamePane() # clicked self
        else $("#avatar-modal-#{uid}").modal('show')

      ###
        Toggle Resting
      ###
      toggleResting: ->
        @pub.set 'preferences.resting', !@pub.get('preferences.resting')
