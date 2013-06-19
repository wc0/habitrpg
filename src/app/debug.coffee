moment = require 'moment'
{algos} = require 'habitrpg-shared'

module.exports.app = (app, model) ->
  user = model.at('_session.user')

  app.fn 'emulateNextDay', ->
    yesterday = +moment().subtract('days', 1).toDate()
    user.set 'lastCron', yesterday
    window.location.reload()

  app.fn 'emulateTenDays', ->
    yesterday = +moment().subtract('days', 10).toDate()
    user.set 'lastCron', yesterday
    window.location.reload()

  app.fn 'cheat', ->
    user.incr 'stats.exp', algos.tnl(user.get('stats.lvl'))
    user.incr 'stats.gp', 1000