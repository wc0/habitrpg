moment = require 'moment'
{algos} = require 'habitrpg-shared'

module.exports.app = (app) ->
  {model} = app

  app.fn
    debug:
      nextDay: ->
        @priv.set 'lastCron', +moment().subtract('days', 1), ->app.user.cron()

      nextTenDays: ->
        @priv.set 'lastCron', +moment().subtract('days', 10), ->app.user.cron()

      cheat: ->
        @pub.increment 'stats.exp', algos.tnl(@pub.get('stats.lvl'))
        @pub.increment 'stats.gp', 1000