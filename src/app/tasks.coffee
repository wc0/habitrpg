{algos, helpers} = require 'habitrpg-shared'
_ = require 'lodash'
moment = require 'moment'
async = require 'async'

###
  Make scoring functionality available to the app
###
module.exports.app = (app) ->
  u = require("./user.coffee")

  ###
  algos.score wrapper for habitrpg-helpers to work in Derby. We need to do model.set() instead of simply setting the
  object properties, and it's very difficult to diff the two objects and find dot-separated paths to set. So we to first
  clone our user object (if we don't do that, it screws with model.on() listeners, ping Tyler for an explaination),
  perform the updates while tracking paths, then all the values at those paths
  ###
  score = (model, taskId, direction, allowUndo=false) ->
    [drop, delta, paths] = [undefined, undefined, {}]
    ats = u.userAts(model)
    gets = {pub: ats.pub.get(), priv: ats.priv.get()}
    uobj = u.transformForAPI(gets.pub, gets.priv)
    tobj = uobj.tasks[taskId]

    # Stuff for undo
    if allowUndo
      tbefore = _.cloneDeep tobj
      async.nextTick ->
        tbefore.completed = !tbefore.completed if tbefore.type in ['daily', 'todo']
        previousUndo = model.get('_page.undo')
        clearTimeout(previousUndo.timeoutId) if previousUndo?.timeoutId
        timeoutId = setTimeout (-> model.del('_page.undo')), 20000
        model.set '_page.undo', {stats:_.cloneDeep(uobj.stats), task: tbefore, timeoutId: timeoutId}

    delta = algos.score(uobj, tobj, direction, {paths})
    model.set('_page.tmp.streakBonus', uobj._tmp.streakBonus) if uobj._tmp?.streakBonus
    drop = uobj._tmp?.drop

    dropCb = ->
      if drop and $?
        model.set '_page.tmp.drop', drop
        $('#item-dropped-modal').modal 'show'
    u.setDiff model, uobj, paths, {cb: dropCb}
    delta

  ###
    This is how we handle app.score for todos & dailies. Due to Derby's special handling of `checked={:task.completd}`,
    the above function doesn't work so we need a listener here
  ###
  app.model.on 'change', '_page.user.priv.tasks.*.completed', (id, value, previous, passed) ->
    return if passed?.cron # Don't do this stuff on cron
    direction = if value then 'up' else 'down'
    score(app.model, id, direction, true)

  app.on 'render', (ctx) ->
    model = @model
    unless model.get('_session.flags.isMobile') is true
      #  ----------------
      #  Setup Date Popups
      #  ----------------
      $('.datepicker').datepicker({autoclose:true, todayBtn:true})
      .on 'changeDate', (ev) ->
          #for some reason selecting a date doesn't fire a change event on the field, meaning our changes aren't saved
          model.at(ev.target).set 'date', moment(ev.date).format('MM/DD/YYYY')

      # ----------------
      # Setup jQuery UI Sortable
      # ----------------
      async.nextTick ->
        ['habit', 'daily', 'todo', 'reward'].forEach (type) ->
          from = null
          list = model.at "_page.lists.tasks.#{model.get('_session.userId')}.#{type}s"
          ul = $("ul.#{type}s")
          ul.sortable
            dropOnEmpty: false
            cursor: "help"
            items: "li"
            scroll: true
            axis: 'y'
            start: (e, ui) ->
              item = ui.item[0]
              from = ul.children().index(item)
            update: (e, ui) ->
              item = ui.item[0]
              to = ul.children().index(item)
              # Use the Derby ignore option to suppress the normal move event
              # binding, since jQuery UI will move the element in the DOM.
              # Also, note that refList index arguments can either be an index
              # or the item's id property
              list.pass(ignore: item.id).move from, to

  app.fn
    tasks:

      ###
        Add task
      ###
      create: (e, el) ->
        {model} = @
        type = $(el).attr('data-task-type')
        newModel = model.at("_page.new.#{type}")
        text = newModel.get()
        # Don't add a blank task; 20/02/13 Added a check for undefined value, more at issue #463 -lancemanfv
        return if /^(\s)*$/.test(text) || text == undefined

        newTask = {id: model.id(), type, text, notes: '', value: 0}
        newTask.tags = _.reduce @priv.get('filters'), ((memo,v,k) -> memo[k]=v if v; memo), {}

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
        #if e.at().path().indexOf(@uid) != -1
        e.at().unshift newTask
        #else
          # see https://github.com/SLaks/racer/issues/14.
          # Very strange issues here. We can unshift onto user tasks just fine, but when we unshift in challenges
          # it completely clobbers the id list. model.push doesn't seem to have the same issues for some reason. We get the
          # same bug if we run `e.at().push newTask, ->e.at().move({id: newTask.id}, 0)`
        #  e.at().push newTask

        newModel.set ''

      ###
        Delete Task
      ###
      del: (e) ->
        return unless confirm("Are you sure you want to delete this task?") is true
        $('[rel=tooltip]').tooltip('hide')
        e.at().remove()
        #@priv.del "tasks.#{e.get('id')}" # we're now using {deleteRemoved: true} on refList

      ###
        Clear Completed
      ###
      clearCompleted: (e, el) ->
        {model, uid} = @
        completedIds =  _.pluck( _.where(model.get("_page.lists.tasks.#{uid}.todos"), {completed:true}), 'id')
        todoIds = @priv.get('ids.todos')

        _.each completedIds, (id) => @priv.del "tasks.#{id}"; true
        @priv.set 'ids.todos', _.difference(todoIds, completedIds)

      ###
        Toggle Day
      ###
      toggleDay: (e, el) ->
        task = @model.at(e.target)
        if /active/.test($(el).attr('class')) # previous state, not current
          task.set('repeat.' + $(el).attr('data-day'), false)
        else
          task.set('repeat.' + $(el).attr('data-day'), true)

      ###
        Toggle Editing
      ###
      toggleTaskEdit: (e, el) ->
        id = e.get('id')
        [editPath, chartPath] = ["_page.editing.tasks.#{id}", "_page.charts.#{id}"]
        @model.set editPath, !(@model.get editPath)
        @model.set chartPath, false

      ###
        Toggle Charts
      ###
      toggleChart: (e, el) ->
        id = $(el).attr('data-id')
        [historyPath, togglePath] = ['','']

        switch id
          when 'exp'
            [togglePath, historyPath] = ['_page.charts.exp', '_page.user.priv.history.exp']
          when 'todos'
            [togglePath, historyPath] = ['_page.charts.todos', '_page.user.priv.history.todos']
          else
            [togglePath, historyPath] = ["_page.charts.#{id}", "_page.user.priv.tasks.#{id}.history"]
            @model.set "_page.editing.tasks.#{id}", false

        history = @model.get(historyPath)
        @model.set togglePath, !(@model.get togglePath)

        matrix = [['Date', 'Score']]
        _.each history, (obj) -> matrix.push([ moment(obj.date).format('MM/DD/YY'), obj.value ]); true
        data = google.visualization.arrayToDataTable matrix
        options =
          title: 'History'
          backgroundColor: { fill:'transparent' }
        chart = new google.visualization.LineChart $(".#{id}-chart")[0]
        chart.draw(data, options)

      ###
        Show Remaining
      ###
      todosShowRemaining: -> @model.set '_page.active.completed', false

      ###
        Show Completed
      ###
      todosShowCompleted: -> @model.set '_page.active.completed', true

      ###
        Call scoring functions for habits & rewards (todos & dailies handled below)
      ###
      score: (e, el) ->
        id = $(el).parents('li').attr('data-id')
        direction = $(el).attr('data-direction')
        score(@model, e.get('id'), direction, true)

      ###
        Undo
      ###
      undo: ->
        model = @model
        undo = model.get '_page.undo'
        clearTimeout(undo.timeoutId) if undo?.timeoutId
        model.del '_page.undo'
        _.each undo.stats, (val, key) => @pub.set "stats.#{key}", val; true
        taskPath = "tasks.#{undo.task.id}"
        _.each undo.task, (val, key) =>
          return true if key in ['id', 'type'] # strange bugs in this world: https://workflowy.com/shared/a53582ea-43d6-bcce-c719-e134f9bf71fd/
          if key is 'completed'
            @priv.pass({cron:true}).set("#{taskPath}.completed",val)
          else
            @priv.set "#{taskPath}.#{key}", val
          true

      ###
        Toggle Advanced Editing Editing
      ###
      toggleAdvanced: (e, el) ->
        $(el).next('.advanced-option').toggleClass('visuallyhidden')

      ###
        Save & Close
      ###
      saveAndClose: ->
        # When they update their notes, re-establish tooltip & popover
        $('[rel=tooltip]').tooltip()
        $('[rel=popover]').popover()

      ###
        Set Task Prio
      ###
      setPriority: (e, el) ->
        dataId = $(el).parent('[data-id]').attr('data-id')
        #"_page.user.priv.tasks.#{dataId}"
        @model.at(e.target).set 'priority', $(el).attr('data-priority')
