moment = require 'moment'
{algos} = require 'habitrpg-shared'
u = require './user.coffee'

module.exports.app = (app, model) ->
  user = u.userAts(model)

  app.fn 'emulateNextDay', ->
    user.priv.set 'lastCron', +moment().subtract('days', 1), ->location.reload()

  app.fn 'emulateTenDays', ->
    user.priv.set 'lastCron', +moment().subtract('days', 10), ->location.reload()

  app.fn 'cheat', ->
    user.pub.increment 'stats.exp', algos.tnl(user.pub.get('stats.lvl'))
    user.pub.increment 'stats.gp', 1000