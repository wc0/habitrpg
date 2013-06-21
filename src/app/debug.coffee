moment = require 'moment'
{algos} = require 'habitrpg-shared'
u = require './user.coffee'

module.exports.app = (app, model) ->
  user = u.userAts(model)

  app.fn 'emulateNextDay', ->
    yesterday = +moment().subtract('days', 1).toDate()
    user.priv.set 'lastCron', yesterday
    window.location.reload()

  app.fn 'emulateTenDays', ->
    yesterday = +moment().subtract('days', 10).toDate()
    user.priv.set 'lastCron', yesterday
    window.location.reload()

  app.fn 'cheat', ->
    user.pub.incr 'stats.exp', algos.tnl(user.pub.get('stats.lvl'))
    user.pub.incr 'stats.gp', 1000