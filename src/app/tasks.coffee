{algos, helpers} = require 'habitrpg-shared'
_ = require 'lodash'
moment = require 'moment'
misc = require './misc.coffee'


###
  Make scoring functionality available to the app
###
module.exports.app = (appExports, model) ->
  user = model.at('_session.user')

  appExports.addTask = (e, el) ->
    type = $(el).attr('data-task-type')
    newModel = model.at('_page.new.' + type.charAt(0).toUpperCase() + type.slice(1))
    text = newModel.get()
    # Don't add a blank task; 20/02/13 Added a check for undefined value, more at issue #463 -lancemanfv
    return if /^(\s)*$/.test(text) || text == undefined

    newTask = {id: model.id(), type, text, notes: '', value: 0}
    newTask.tags = _.reduce user.get('filters'), ((memo,v,k) -> memo[k]=v if v; memo), {}

    switch type
      when 'habit'
        newTask = _.defaults {up: true, down: true}, newTask
      when 'reward'
        newTask = _.defaults {value: 20}, newTask
      when 'daily'
        newTask = _.defaults {repeat:{su:true,m:true,t:true,w:true,th:true,f:true,s:true}, completed: false }, newTask
      when 'todo'
        newTask = _.defaults {completed: false }, newTask

    # e.at() is the list, which was scoped here using {#with @list}...{/}
    if e.at().path().indexOf(user.get('id')) != -1
      e.at().unshift newTask
    else
      # see https://github.com/SLaks/racer/issues/14.
      # Very strange issues here. We can unshift onto user tasks just fine, but when we unshift in challenges
      # it completely clobbers the id list. model.push doesn't seem to have the same issues for some reason. We get the
      # same bug if we run `e.at().push newTask, ->e.at().move({id: newTask.id}, 0)`
      e.at().push newTask

    newModel.set ''

  appExports.del = (e) ->
    return unless confirm("Are you sure you want to delete this task?") is true
    $('[rel=tooltip]').tooltip('hide')
    user.del "tasks.#{e.get('id')}"
    e.at().remove()


  appExports.clearCompleted = (e, el) ->
    completedIds =  _.pluck( _.where(model.get("_page.lists.tasks.#{user.get('id')}.todos"), {completed:true}), 'id')
    todoIds = user.get('todoIds')

    _.each completedIds, (id) -> user.del "tasks.#{id}"; true
    user.set 'todoIds', _.difference(todoIds, completedIds)

  appExports.toggleDay = (e, el) ->
    task = model.at(e.target)
    if /active/.test($(el).attr('class')) # previous state, not current
      task.set('repeat.' + $(el).attr('data-day'), false)
    else
      task.set('repeat.' + $(el).attr('data-day'), true)

  appExports.toggleTaskEdit = (e, el) ->
    id = e.get('id')
    [editPath, chartPath] = ["_page.editing.tasks.#{id}", "_page.charts.#{id}"]
    model.set editPath, !(model.get editPath)
    model.set chartPath, false

  appExports.toggleChart = (e, el) ->
    id = $(el).attr('data-id')
    [historyPath, togglePath] = ['','']

    switch id
      when 'exp'
        [togglePath, historyPath] = ['_page.charts.exp', '_session.user.history.exp']
      when 'todos'
        [togglePath, historyPath] = ['_page.charts.todos', '_session.user.history.todos']
      else
        [togglePath, historyPath] = ["_page.charts.#{id}", "_session.user.tasks.#{id}.history"]
        model.set "_page.editing.tasks.#{id}", false

    history = model.get(historyPath)
    model.set togglePath, !(model.get togglePath)

    matrix = [['Date', 'Score']]
    _.each history, (obj) -> matrix.push([ moment(obj.date).format('MM/DD/YY'), obj.value ])
    data = google.visualization.arrayToDataTable matrix
    options =
      title: 'History'
      backgroundColor: { fill:'transparent' }
    chart = new google.visualization.LineChart $(".#{id}-chart")[0]
    chart.draw(data, options)

  appExports.todosShowRemaining = -> model.set '_page.active.completed', false
  appExports.todosShowCompleted = -> model.set '_page.active.completed', true

  ###
    Call scoring functions for habits & rewards (todos & dailies handled below)
  ###
  appExports.score = (e, el) ->
    id = $(el).parents('li').attr('data-id')
    direction = $(el).attr('data-direction')
    misc.score(model, id, direction, true)

  ###
    This is how we handle appExports.score for todos & dailies. Due to Derby's special handling of `checked={:task.completd}`,
    the above function doesn't work so we need a listener here
  ###
  user.on 'set', 'tasks.*.completed', (i, completed, previous, isLocal, passed) ->
    return if passed?.cron # Don't do this stuff on cron
    direction = if completed then 'up' else 'down'
    misc.score(model, i, direction, true)

  ###
    Undo
  ###
  appExports.undo = () ->
    undo = model.get '_page.undo'
    clearTimeout(undo.timeoutId) if undo?.timeoutId
    model.del '_page.undo'
    _.each undo.stats, (val, key) -> user.set "stats.#{key}", val; true
    taskPath = "tasks.#{undo.task.id}"
    _.each undo.task, (val, key) ->
      return true if key in ['id', 'type'] # strange bugs in this world: https://workflowy.com/shared/a53582ea-43d6-bcce-c719-e134f9bf71fd/
      if key is 'completed'
        user.pass({cron:true}).set("#{taskPath}.completed",val)
      else
        user.set "#{taskPath}.#{key}", val
      true

  appExports.tasksToggleAdvanced = (e, el) ->
    $(el).next('.advanced-option').toggleClass('visuallyhidden')

  appExports.tasksSaveAndClose = ->
    # When they update their notes, re-establish tooltip & popover
    $('[rel=tooltip]').tooltip()
    $('[rel=popover]').popover()

  appExports.tasksSetPriority = (e, el) ->
    dataId = $(el).parent('[data-id]').attr('data-id')
    #"_session.user.tasks.#{dataId}"
    model.at(e.target).set 'priority', $(el).attr('data-priority')
