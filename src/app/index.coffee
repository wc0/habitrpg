app = require('derby').createApp module

# Include library components
app
  .use(require('derby-ui-boot'), {styles: []})
  .use(require('../../ui'))
  .use(require 'derby-auth/components')

# Translations
i18n = require './i18n.coffee'
i18n.localize app,
  availableLocales: ['en', 'he', 'bg', 'nl']
  defaultLocale: 'en'
  urlScheme: false
  checkHeader: true

misc = require('./misc.coffee')
misc.viewHelpers app.view

_ = require('lodash')
{algos} = require 'habitrpg-shared'

###
  Subscribe to the user, the users's party (meta info like party name, member ids, etc), and the party's members. 3 subscriptions.
###
setupSubscriptions = (page, model, params, next, cb) ->
  uuid = model.get '_session.userId'

  ###
  Queries
  ###
  $self = model.at "users.#{uuid}"
  $publicGroups = model.query 'groups',
    privacy: 'public'
    type: 'guild'
    #.only(['id', 'type', 'name', 'description', 'members' , 'privacy'])
  $myGroups = model.query 'groups',
    members: {$in: [uuid]}
    #.only(['id', 'type', 'name', 'description', 'members' , 'privacy'])

  model.fetch $publicGroups, $myGroups, (err) ->
    return next(err) if err

    descriptors = []; paths = []
    finished = ->
      # Add public "Tavern" guild in
      descriptors.unshift(model.at 'groups.habitrpg'); paths.unshift('_page.tavern')
      descriptors.unshift($self); paths.unshift('_session.user')

      # Subscribe to each descriptor
      model.subscribe.apply model, descriptors.concat (err) ->
        return next(err) if err
        _.each descriptors, ((d, i) -> model.ref paths[i], descriptors[i]; true)
        unless model.get('_session.user')
          console.error "User not found - this shouldn't be happening!"
          return page.redirect('/logout') #delete model.session.userId
        return cb()

    # Get public groups first, order most-to-least # subscribers
    # FIXME use a filter instead
    model.set '_page.publicGroups', _.sortBy($publicGroups.get(), (g) -> -_.size(g.members))

    groupsObj = $myGroups.get()

    # (1) Solo player
    return finished() if _.isEmpty(groupsObj)

    ## (2) Party or Guild has members, fetch those users too
    # Subscribe to the groups themselves. We separate them by _page.party, _page.guilds, and _page.tavern (the "global" guild).
    groupsInfo = _.reduce groupsObj, ((m,g)->
      if g.type is 'guild' then m.guildIds.push(g.id) else m.partyId = g.id
      m.members = m.members.concat(g.members)
      m
    ), {guildIds:[], partyId:null, members:[]}

    # Fetch, not subscribe. There's nothing dynamic we need from members, just the the Group (below) which includes chat, challenges, etc
    $members = model.query 'users',
      _id: {$in: groupsInfo.members}
      #.only 'stats','items','invitations','profile','achievements','backer','preferences','auth.local.username','auth.facebook.displayName'
    $members.fetch (err) ->
      return next(err) if err
      # we need _page.members as an object in the view, so we can iterate over _page.party.members as :id, and access _page.members[:id] for the info
      mObj = #members.get()
      model.set "_page.members", _.object(_.pluck(mObj,'id'), mObj)
      model.set "_page.membersArray", mObj

      if groupsInfo.partyId
        descriptors.unshift model.at "groups.#{groupsInfo.partyId}"
        paths.unshift '_page.party'
      unless _.isEmpty(groupsInfo.guildIds)
        descriptors.unshift model.query 'groups',
          _id: {$in: groupsInfo.guildIds}
        paths.unshift '_page.guilds'
      finished descriptors, paths


# ========== ROUTES ==========

app.get '/', (page, model, params, next) ->
  return page.redirect '/' if page.params?.query?.play?

  # removed force-ssl (handled in nginx), see git for code
  setupSubscriptions page, model, params, next, ->
    require('./items.coffee').server(model)
    misc.setupRefLists(model)
    page.render()


# ========== CONTROLLER FUNCTIONS ==========

app.ready (model) ->
  user = model.at('_session.user')

  #FIXME this should only be called once, on initial empty database
  model.setNull "groups.habitrpg",
    chat: []
    id: "habitrpg"
    leader: "9"
    name: "HabitRPG"
    type: "guild"

  browser = require './browser.coffee'
  require('./tasks.coffee').app(app, model)
  require('./items.coffee').app(app, model)
  require('./groups.coffee').app(app, model)
  require('./profile.coffee').app(app, model)
  require('./pets.coffee').app(app, model)
  require('../server/private.coffee').app(app, model)
  require('./debug.coffee').app(app, model) unless model.get('_session.flags.nodeEnv') is 'production'
  browser.app(app, model)
  require('./unlock.coffee').app(app, model)
  require('./filters.coffee').app(app, model)
  require('./challenges.coffee').app(app, model)

  # used for things like remove website, chat, etc
  app.fn 'removeAt', (e, el) ->
    if (confirmMessage = $(el).attr 'data-confirm')?
      return unless confirm(confirmMessage) is true
    e.at().remove()
    browser.resetDom(model) if $(el).attr('data-refresh')

  ###
    Cron
  ###
  misc.batchTxn model, (uObj, paths) ->
    # habitrpg-shared/algos requires uObj.habits, uObj.dailys etc instead of uObj.tasks
    _.each ['habit','daily','todo','reward'], (type) -> uObj["#{type}s"] = _.where(uObj.tasks, {type}); true
    algos.cron uObj, {paths}
    # for new user, just set lastCron - no need to reset dom.
    # remember that the properties are set from uObj & paths AFTER the return of this callback
    return if _.isEmpty(paths) or (paths['lastCron'] and _.size(paths) is 1)
    # for everyone else, we need to reset dom - too many changes have been made and won't it breaks dom listeners.
    if lostHp = delete paths['stats.hp'] # we'll set this manually so we can get a cool animation
      setTimeout ->
        browser.resetDom(model)
        user.set 'stats.hp', uObj.stats.hp
      , 750
  ,{cron:true}
