_ = require 'lodash'
helpers = require 'habitrpg-shared/script/helpers'
async = require 'async'
misc = require './misc'

module.exports.app = (appExports, model) ->
  browser = require './browser'
  user = model.at '_user'

  ###
    Add challenge name as a tag for user
  ###
  syncChalToUser = (chal) ->
    misc.batchTxn model, (uObj, paths, batch) ->
      # Sync tags
      tags = uObj.tags || []
      found = _.findIndex tags, {id: chal.id}
      if found != -1 and tags[found].name != chal.name
        # update the name - it's been changed since
        batch.set "tags.#{found}.name", chal.name
      else
        #we know better than to model.push
        batch.set 'tags', tags.concat({id: chal.id, name: chal.name, challenge: true})

      tags = {}; tags[chal.id] = true
      _.each chal.tasks, (task) ->
        _.defaults task, { tags, challenge: chal.id, group: {id: chal.group.id, type: chal.group.type} }
        path = "tasks.#{task.id}"
        if uObj.tasks[task.id]
          batch.set path, _.defaults(task, batch.get path)
        else
          batch.set path, task
          batch.set "#{task.type}Ids", batch.get("#{task.type}Ids").concat(task.id)
        true

  ###
    Sync any updates to challenges since last refresh
    challenge->user sync. user->challenge happens when user interacts with their taskss
  ###
  _.each model.get('groups'), (g) ->
    if (user.get('id') in g.members) and g.challenges
      _.each g.challenges, syncChalToUser

  ###
    Render graphs for user scores when the "Challenges" tab is clicked
  ###
  $('#profile-challenges-tab-link').on 'shown', ->
    async.each _.toArray(model.get('groups')), (g) ->
      async.each _.toArray(g.challenges), (chal) ->
        async.each _.toArray(chal.tasks), (task) ->
          async.each _.toArray(chal.users), (member) ->
            if (history = member?["#{task.type}s"]?[task.id]?.history) and !!history
              data = google.visualization.arrayToDataTable _.map(history, (h)-> [h.date,h.value])
              options =
                backgroundColor: { fill:'transparent' }
                width: 150
                height: 50
                chartArea: width: '80%', height: '80%'
                axisTitlePosition: 'none'
                legend: position: 'bottom'
                hAxis: gridlines: color: 'transparent' # since you can't seem to *remove* gridlines...
                vAxis: gridlines: color: 'transparent'
              chart = new google.visualization.LineChart $(".challenge-#{chal.id}-member-#{member.id}-history-#{task.id}")[0]
              chart.draw(data, options)


  appExports.challengeCreate = (e,el) ->
    [type, gid] = [$(el).attr('data-type'), $(el).attr('data-gid')]
    cid = model.id()
    model.set '_page.new.challenge',
      id: cid
      name: ''
      tasks: {}
      ids:
        habits: []
        dailys: []
        todos: []
        rewards: []
      user:
        uid: user.get('id')
        name: helpers.username(model.get('_user.auth'), model.get('_user.profile.name'))
      group: {type, id:gid}
      timestamp: +new Date
    _.each ['habits','dailys','todos','rewards'], (type) ->
      model.refList "_page.lists.tasks.#{cid}.#{type}", "_page.new.challenge.tasks", "_page.new.challenge.ids.#{type}"

  appExports.challengeSave = ->
    newChal = model.get('_page.new.challenge')
    [gid, cid] = [newChal.group.id, newChal.id]
    model.unshift "_page.lists.challenges.#{gid}", newChal, ->
      _.each ['habits','dailys','todos','rewards'], (type) ->
        model.del "_page.lists.tasks.#{cid}.#{type}" #remove old refList
        model.refList "_page.lists.tasks.#{cid}.#{type}", "groups.#{gid}.challenges.#{cid}.tasks", "groups.#{gid}.challenges.#{cid}.ids.#{type}"
      browser.growlNotification('Challenge Created','success')
      challengeDiscard()

  appExports.toggleChallengeEdit = (e, el) ->
    path = "_page.editing.challenges.#{$(el).attr('data-id')}"
    model.set path, !model.get(path)

  appExports.challengeDiscard = challengeDiscard = -> model.del '_page.new.challenge'

  appExports.challengeDelete = (e) ->
    return unless confirm("Delete challenge, are you sure?") is true
    chal = e.get()
    path = "groups.#{chal.group.id}.ids.challenges"
    debugger
    if (i = model.get(path).indexOf chal.id) != -1
      ids = model.get(path); ids.splice(i, 1)
      model.set path, ids
      e.at().del()

  appExports.challengeSubscribe = (e) ->
    chal = e.get()
    # Add all challenge's tasks to user's tasks
    userChallenges = user.get('challenges')
    user.unshift('challenges', chal.id) unless userChallenges and (userChallenges.indexOf(chal.id) != -1)
    e.at().set "users", (chal.users || []).concat
      id: user.get('id')
      name: helpers.username(user.get('auth'), user.get('profile.name'))
    syncChalToUser(chal)

  appExports.challengeUnsubscribe = (e, el) ->
    $(el).popover('destroy').popover({
      html: true
      placement: 'top'
      trigger: 'manual'
      title: 'Unsubscribe From Challenge And:'
      content: """
               <a class=challenge-unsubscribe-and-remove>Remove Tasks</a><br/>
               <a class=challenge-unsubscribe-and-keep>Keep Tasks</a><br/>
               <a class=challenge-unsubscribe-cancel>Cancel</a><br/>
               """
    }).popover('show')

    unsubscribe = (remove = false) ->
      uid = user.get('id')
      chal = e.get()
      i = user.get('challenges')?.indexOf chal.id
      user.remove("challenges.#{i}") if i? and i != -1
      if (i = _.findIndex chal.users, {id:user.get('id')}) != -1
        chal.users.splice(i,1)
        e.at().set 'users', chal.users
      async.each _.toArray(chal.tasks), (task) ->
        if remove is true
          if (i = _.findIndex(user.get("#{task.type}Ids",{id:task.id}))) != -1
            ids = user.get("#{task.type}Ids"); ids.splice(i,1)
            user.set "#{task.type}Ids", ids
            user.del "tasks.#{task.id}"
        else
          user.del "tasks.#{task.id}.challenge"
        true
    $('.challenge-unsubscribe-and-remove').click -> unsubscribe(true)
    $('.challenge-unsubscribe-and-keep').click -> unsubscribe(false)
    $('[class^=challenge-unsubscribe]').click -> $(el).popover('destroy')