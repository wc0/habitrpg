app = require('derby').createApp module
async = require 'async'

# Include library components
app
  .use(require('derby-ui-boot'), {styles: []})
  .use(require('../../ui'))
  .use(require 'derby-auth/components/index.coffee')

# Translations
i18n = require './i18n.coffee'
i18n.localize app,
  availableLocales: ['en', 'he', 'bg', 'nl']
  defaultLocale: 'en'
  urlScheme: false
  checkHeader: true

require('./viewHelpers.coffee')(app.view)
_ = require('lodash')
{algos, helpers} = require 'habitrpg-shared'

###
  Subscribe to the user, the users's party (meta info like party name, member ids, etc), and the party's members. 3 subscriptions.
###
setupSubscriptions = (page, model, params, next, cb) ->
  uuid = model.get '_session.userId'

  ###
  Queries
  ###
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
      # Add in the thing's we'll subscribe to unconditionally. tavern, public/private self docs
      descriptors.unshift(model.at 'groups.habitrpg');      paths.unshift('_page.tavern')
      descriptors.unshift(model.at "usersPublic.#{uuid}");  paths.unshift('_page.user.pub')
      descriptors.unshift(model.at "usersPrivate.#{uuid}"); paths.unshift('_page.user.priv')
      descriptors.unshift(model.at "auths.#{uuid}");        paths.unshift('_page.auth')

      # Subscribe to each descriptor
      model.subscribe.apply model, descriptors.concat (err) ->
        return next(err) if err
        _.each descriptors, (d, i) ->
          if descriptors[i]._at? then model.ref paths[i], descriptors[i]
          else descriptors[i].ref paths[i]
          true
        unless model.get('_page.user.pub')
          console.error "User not found - this shouldn't be happening!"
          return page.redirect('/logout') #delete req.session.userId
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
    $members = model.query 'usersPublic',
      _id: {$in: groupsInfo.members}
      #.only 'stats','items','invitations','profile','achievements','backer','preferences','auth.local.username','auth.facebook.displayName'
    $members.fetch (err) ->
      return next(err) if err
      # we need _page.members as an object in the view, so we can iterate over _page.party.members as :id, and access _page.members[:id] for the info
      mObj = $members.get()
      model.set "_page.members", _.object(_.pluck(mObj,'id'), mObj)
      model.set "_page.membersArray", mObj

      if groupsInfo.partyId
        descriptors.unshift model.at "groups.#{groupsInfo.partyId}"
        paths.unshift '_page.party'
      unless _.isEmpty(groupsInfo.guildIds)
        descriptors.unshift model.query('groups', _id: $in: groupsInfo.guildIds)
        paths.unshift '_page.guilds'
      finished()

setupRefLists = (model) ->
  types = ['habit', 'daily', 'todo', 'reward']
  uid = model.get('_session.userId')

  ## User
  _.each types, (type) ->
    model.refList "_page.lists.tasks.#{uid}.#{type}s", "_page.user.priv.tasks", "_page.user.priv.ids.#{type}s"
    true

  return # Until we get challenges in
  ## Groups
  _.each model.get('groups'), (g) ->
    gpath = "groups.#{g.id}"
    model.refList "_page.lists.challenges.#{g.id}", "#{gpath}.challenges", "#{gpath}.ids.challenges"
    true

    ## Groups -> Challenges
    _.each g.challenges, (c) ->
      _.each types, (type) ->
        cpath = "challenges.#{c.id}"
        model.refList "_page.lists.tasks.#{c.id}.#{type}s", "#{gpath}.#{cpath}.tasks", "#{gpath}.#{cpath}.ids.#{type}s"
        true
      true

#FIXME move this to a callback of derby-auth post-registration, so it's only called once on registration
initProfileName = (model, cb) ->
  return cb() unless model.get("_session.loggedIn")
  candidate = helpers.usernameCandidates(model.get('_page.auth'))
  if candidate? then model.setNull("_page.user.pub.profile.name", candidate, cb)
  else cb()

# ========== ROUTES ==========

app.get '/', (page, model, params, next) ->
  # removed force-ssl (handled in nginx), see git for code
  return page.redirect '/' if page.params?.query?.play?
  setupSubscriptions page, model, params, next, ->
    require('./items.coffee').server(model)
    setupRefLists(model)
    initProfileName model, ->page.render()

# ========== CONTROLLER FUNCTIONS ==========

app.ready (model) ->
  u = require './user.coffee'
  user = u.userAts(model)

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
  #require('./challenges.coffee').app(app, model)

  # used for things like remove website, chat, etc
  app.fn 'removeAt', (e, el) ->
    if (confirmMessage = $(el).attr 'data-confirm')?
      return unless confirm(confirmMessage) is true
    e.at().remove()
    #browser.resetDom(model) if $(el).attr('data-refresh')

  ###
    Cron
  ###
  async.nextTick ->
    uobj = u.transformForAPI model.get('_page.user.pub'), model.get('_page.user.priv')
    paths = {}
    algos.cron uobj, {paths}
    if _.size(paths) > 0
      if (delete paths['stats.hp'])? # we'll set this manually so we can get a cool animation
        hp = uobj.stats.hp
        setTimeout ->
          # we need to reset dom - too many changes have been made and won't it breaks dom listeners.
          #browser.resetDom(model)
          user.pub.set 'stats.hp', hp
        , 500
      u.setDiff model, uobj, paths, {pass: cron: true}
      #_.each paths, (v,k) -> user.pass({cron:true}).set(k,helpers.dotGet(k, uObj));true
