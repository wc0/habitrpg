_ = require 'lodash'
{helpers} = require 'habitrpg-shared'

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
module.exports.transformForDerby = (user) ->
  obj =
    pub: id: user.id
    priv: id: user.id
  _.each user, (v,k) ->
    if k in properties.pub then obj.pub[k] = v
    else if k in properties.priv then obj.priv[k] = v
    true
  toObj = (arr) -> _.object _.pluck(arr, 'id'), arr
  obj.priv.tasks = toObj user.habits.concat(user.dailys).concat(user.todos).concat(user.rewards)
  obj.priv.ids =
    habits: _.pluck user.habits, 'id'
    dailys: _.pluck user.dailys, 'id'
    todos: _.pluck user.todos, 'id'
    rewards: _.pluck user.rewards, 'id'
  obj

###
Transform the schema provided by Derby so it can be consumed by API / Helpers
###
module.exports.transformForAPI = (pub, priv) ->
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
module.exports.setDiff = (model, obj, paths, options={}) ->
  _.defaults options, {pass:{}, cb: ->}

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





