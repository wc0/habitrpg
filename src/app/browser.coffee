_ = require 'lodash'
moment = require 'moment'
async = require 'async'

###
  Setup jQuery UI Sortable
###
setupSortable = (model) ->
  return if (model.get('_session.flags.isMobile') is true) #don't do sortable on mobile
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
        start: (e, ui) =>
          item = ui.item[0]
          from = ul.children().index(item)
        update: (e, ui) =>
          item = ui.item[0]
          to = ul.children().index(item)
          # Use the Derby ignore option to suppress the normal move event
          # binding, since jQuery UI will move the element in the DOM.
          # Also, note that refList index arguments can either be an index
          # or the item's id property
          debugger
          list.pass(ignore: item.id).move from, to

setupTooltips = module.exports.setupTooltips = ->
  $('[rel=tooltip]').tooltip()
  $('[rel=popover]').popover()
  $('.popover-auto-show').popover('show')

  $('.priority-multiplier-help').popover
    title: "How difficult is this task?"
    trigger: "hover"
    content: "This multiplies its point value. Use sparingly, rely instead on our organic value-adjustment algorithms. But some tasks are grossly more valuable (Write Thesis vs Floss Teeth). Click for more info."

setupTour = (model) ->
  tourSteps = [
    {
      element: ".main-herobox"
      title: "Welcome to HabitRPG"
      content: "Welcome to HabitRPG, a habit-tracker which treats your goals like a Role Playing Game."
    }
    {
      element: "#bars"
      title: "Achieve goals and level up"
      content: "As you accomplish goals, you level up. If you fail your goals, you lose hit points. Lose all your HP and you die."
    }
    {
      element: "ul.habits"
      title: "Habits"
      content: "Habits are goals that you constantly track."
      placement: "bottom"
    }
    {
      element: "ul.dailys"
      title: "Dailies"
      content: "Dailies are goals that you want to complete once a day."
      placement: "bottom"
    }
    {
      element: "ul.todos"
      title: "Todos"
      content: "Todos are one-off goals which need to be completed eventually."
      placement: "bottom"
    }
    {
      element: "ul.rewards"
      title: "Rewards"
      content: "As you complete goals, you earn gold to buy rewards. Buy them liberally - rewards are integral in forming good habits."
      placement: "bottom"
    }
    {
      element: "ul.habits li:first-child"
      title: "Hover over comments"
      content: "Different task-types have special properties. Hover over each task's comment for more information. When you're ready to get started, delete the existing tasks and add your own."
      placement: "right"
    }
  ]

  $('.main-herobox').popover('destroy') #remove previous popovers
  tour = new Tour()
  tourSteps.forEach (step) -> tour.addStep _.defaults step, {html:true}
  tour._current = 0 if isNaN(tour._current) #bootstrap-tour bug
  tour.start()


# jquery sticky header on scroll, no need for position fixed
initStickyHeader = (model) ->
  $('.header-wrap').sticky({topSpacing:0})

growlNotification = module.exports.growlNotification = (html, type) ->
  $.bootstrapGrowl html,
    ele: '#notification-area',
    type: type # (null, 'info', 'error', 'success', 'gp', 'xp', 'hp', 'lvl','death')
    top_offset: 20
    align: 'right' # ('left', 'right', or 'center')
    width: 250 # (integer, or 'auto')
    delay: 3000
    allow_dismiss: true
    stackup_spacing: 10 # spacing between consecutive stacecked growls.

###
  Sets up "+1 Exp", "Level Up", etc notifications
###
setupGrowlNotifications = (model) ->
  return unless jQuery? # Only run this in the browser
  uPub = model.at '_page.user.pub'

  statsNotification = (html, type) ->
    return if uPub.get('stats.lvl') == 0 #don't show notifications if user dead
    growlNotification(html, type)

  # Setup listeners which trigger notifications
  uPub.on 'change', 'stats.hp', (captures, args) ->
    num = captures - args
    rounded = Math.abs(num.toFixed(1))
    if num < 0
      statsNotification "<i class='icon-heart'></i> - #{rounded} HP", 'hp' # lost hp from purchase
    else if num > 0
      statsNotification "<i class='icon-heart'></i> + #{rounded} HP", 'hp' # gained hp from potion/level? 

  uPub.on 'change', 'stats.exp', (captures, args, isLocal, silent=false) ->
    # unless silent
    num = captures - args
    rounded = Math.abs(num.toFixed(1))
    if num < 0 and num > -50 # TODO fix hackey negative notification supress
      statsNotification "<i class='icon-star'></i> - #{rounded} XP", 'xp'
    else if num > 0
      statsNotification "<i class='icon-star'></i> + #{rounded} XP", 'xp'

  ###
    Show "+ 5 {gold_coin} 3 {silver_coin}"
  ###
  showCoins = (money) ->
    absolute = Math.abs(money)
    gold = Math.floor(absolute)
    silver = Math.floor((absolute-gold)*100)
    if gold and silver > 0
      return "#{gold} <i class='icon-gold'></i> #{silver} <i class='icon-silver'></i>"
    else if gold > 0
      return "#{gold} <i class='icon-gold'></i>"
    else if silver > 0
      return "#{silver} <i class='icon-silver'></i>"

  uPub.on 'change', 'stats.gp', (captures, args) ->
    money = captures - args
    return unless !!money # why is this happening? gotta find where stats.gp is being set from (-)habit
    sign = if money < 0 then '-' else '+'
    statsNotification "#{sign} #{showCoins(money)}", 'gp'

    # Append Bonus
    bonus = model.get('_page.tmp.streakBonus')
    if (money > 0) and !!bonus
      bonus = 0.01 if bonus < 0.01
      statsNotification "+ #{showCoins(bonus)}  Streak Bonus!"
      model.del('_page.tmp.streakBonus')

  uPub.on 'change', 'items.*', (item, after, before) ->
    if item in ['armor','weapon','shield','head'] and +after < +before
      item = 'helm' if item is 'head' # don't want to day "lost a head"
      statsNotification "<i class='icon-death'></i> Respawn!", "death"

  uPub.on 'change', 'stats.lvl', (captures, args) ->
    if captures > args
      statsNotification '<i class="icon-chevron-up"></i> Level Up!', 'lvl'

module.exports.app = (app) ->
  {model} = app

  app.fn
    resetDom: ->
      app.dom.clear()
      app.view.render @model, app.view._lastRender.ns, app.view._lastRender.context

  setupGrowlNotifications(model) unless model.get('_session.flags.isMobile')

  app.on 'render', (ctx) ->
    #restoreRefs(model)
    setupSortable(model)
    setupTooltips(model)
    setupTour(model)
    initStickyHeader(model) unless model.get('_session.flags.isMobile')
    $('.datepicker').datepicker({autoclose:true, todayBtn:true})
      .on 'changeDate', (ev) ->
        #for some reason selecting a date doesn't fire a change event on the field, meaning our changes aren't saved
        model.at(ev.target).set 'date', moment(ev.date).format('MM/DD/YYYY')

    ###
    External Scripts
      JS files not needed right away (google charts) or entirely optional (analytics)
      Each file getsload asyncronously via $.getScript, so it doesn't bog page-load
      These need to be handled in app.on('render'), see https://groups.google.com/forum/?fromgroups=#!topic/derbyjs/x8FwdTLEuXo
    ###
    async.nextTick ->

      # -- Stripe --
      $.getScript('//checkout.stripe.com/v2/checkout.js')

      # -- Google Analytics --
      # Note, Google Analyatics giving beef if in this file. Moved back to index.html. It's ok, it's async - really the
      # syncronous requires up top are what benefit the most from this file.
      if model.get('_session.flags.nodeEnv') is 'production'
        window._gaq = [["_setAccount", "UA-33510635-1"], ["_setDomainName", "habitrpg.com"], ["_trackPageview"]]
        $.getScript ((if "https:" is document.location.protocol then "https://ssl" else "http://www")) + ".google-analytics.com/ga.js"

      # -- Amazon Affiliate --
      #if model.get('_page.user.priv.flags.ads') isnt 'hide'
      #  $.getScript '//pagead2.googlesyndication.com/pagead/js/adsbygoogle.js'
      #  (window.adsbygoogle ?= []).push({})

      unless (model.get('_session.flags.isMobile') is true)

        # -- AddThis--
        $.getScript("//s7.addthis.com/js/250/addthis_widget.js#pubid=lefnire")

        # -- Google Charts --
        $.getScript "//www.google.com/jsapi", ->
          # Specifying callback in options param is vital! Otherwise you get blank screen, see http://stackoverflow.com/a/12200566/362790
          google.load "visualization", "1", {packages:["corechart"], callback: ->}

