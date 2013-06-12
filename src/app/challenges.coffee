_ = require 'lodash'
helpers = require 'habitrpg-shared/script/helpers'

module.exports.app = (appExports, model) ->
  browser = require './browser'
  user = model.at '_user'

  $('#profile-challenges-tab-link').on 'show', (e) ->
    _.each model.get('groups'), (g) ->
      _.each g.challenges, (chal) ->
        _.each ['habit','daily','todo'], (type) ->
          _.each chal["#{type}s"], (task) ->
            _.each chal.users, (member) ->
              if (history = member?["#{type}s"]?[task.id]?.history) and !!history
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
      model.refList "_page.lists.challenges.#{cid}.#{type}", "_page.new.challenge.tasks", "_page.new.challenge.ids.#{type}"

  appExports.challengeSave = ->
    debugger
    newChal = model.get('_page.new.challenge')
    [gid, cid] = [newChal.group.id, newChal.id]
    model.unshift "_page.lists.groups.#{gid}.challenges", newChal, ->
      debugger
      _.each ['habits','dailys','todos','rewards'], (type) ->
        model.del "_page.lists.challenges.#{cid}.#{type}" #remove old refList
        model.refList "_page.lists.challenges.#{cid}.#{type}", "groups.#{gid}.challenges.#{cid}.tasks", "groups.#{gid}.challenges.#{cid}.ids.#{type}"
      browser.growlNotification('Challenge Created','success')
      challengeDiscard()

  appExports.toggleChallengeEdit = (e, el) ->
    path = "_page.editing.challenges.#{$(el).attr('data-id')}"
    model.set path, !model.get(path)

  appExports.challengeDiscard = challengeDiscard = -> model.del '_page.new.challenge'

  appExports.challengeSubscribe = (e) ->
    chal = e.get()

    # Add challenge name as a tag for user
    tags = user.get('tags')
    unless tags and _.find(tags,{id: chal.id})
      model.push '_user.tags', {id: chal.id, name: chal.name, challenge: true}

    tags = {}; tags[chal.id] = true
    # Add all challenge's tasks to user's tasks
    userChallenges = user.get('challenges')
    user.unshift('challenges', chal.id) unless userChallenges and (userChallenges.indexOf(chal.id) != -1)
    _.each chal.tasks, (task) ->
      task.tags = tags
      task.challenge = chal.id
      task.group = {id: chal.group.id, type: chal.group.type}
      model.push("_#{task.type}List", task)
      true

  appExports.challengeUnsubscribe = (e) ->
    chal = e.get()
    i = user.get('challenges')?.indexOf chal.id
    user.remove("challenges.#{i}") if i? and i != -1
    _.each chal.tasks, (task) ->
      model.remove "_#{type}List", _.findIndex(model.get("_#{type}List",{id:task.id}))
      model.del "_user.tasks.#{task.id}"
      true
