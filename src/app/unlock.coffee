_ = require 'lodash'
{helpers, items} = require 'habitrpg-shared'
{ randomVal } = helpers
{ pets, hatchingPotions } = items.items

###
  Listeners to enabled flags, set notifications to the user when they've unlocked features
###

module.exports.app = (app) ->
  {model} = app
  [pub, priv, uid] = [model.at('_page.user.pub'), model.at('_page.user.priv'), model.get('_session.userId')]

  alreadyShown = (before, after) -> !(!before and after is true)

  showPopover = (selector, title, html, placement='bottom') ->
    $(selector).popover('destroy')
    html += " <a href='#' onClick=\"$('#{selector}').popover('hide');return false;\">[Close]</a>"
    $(selector).popover({
      title: title
      placement: placement
      trigger: 'manual'
      html: true
      content: html
    }).popover 'show'


  priv.on 'change', 'flags.customizationsNotification', (value, previous) ->
    return if alreadyShown(previous, value)
    $('.main-herobox').popover('destroy') #remove previous popovers
    html = "Click your avatar to customize your appearance."
    showPopover '.main-herobox', 'Customize Your Avatar', html, 'bottom'

  priv.on 'change', 'flags.itemsEnabled', (value, previous) ->
    return if alreadyShown(previous, value)
    html = """
           <img src='/vendor/BrowserQuest/client/img/1/chest.png' />
           Congratulations, you have unlocked the Item Store! You can now buy weapons, armor, potions, etc. Read each item's comment for more information.
           """
    showPopover 'div.rewards', 'Item Store Unlocked', html, 'left'

  priv.on 'change', 'flags.petsEnabled', (value, previous) ->
    return if alreadyShown(previous,value)
    html = """
           <img src='/img/sprites/wolf_border.png' style='width:30px;height:30px;float:left;padding-right:5px' />
           You have unlocked Pets! You can now buy pets with Gems (note, you replenish Gems with real-life money - so chose your pets wisely!)
           """
    showPopover '#rewardsTabs', 'Pets Unlocked', html, 'left'

  priv.on 'change', 'flags.partyEnabled', (value, previous) ->
    return if alreadyShown(previous,value)
    html = """
           Be social, join a party and play Habit with your friends! You'll be better at your habits with accountability partners. Click User -> Options -> Party, and follow the instructions. LFG anyone?
           """
    showPopover '.user-menu', 'Party System', html, 'bottom'

  priv.on 'change', 'flags.dropsEnabled', (value, previous) ->
    return if alreadyShown(previous,value)
    egg = randomVal pets
    pub.push 'items.eggs', egg

    $('#drops-enabled-modal').modal 'show'

  pub.on 'insert', 'items.pets', (value, previous) ->
    return if pub.get('achievements.beastMaster')
    if previous >= 90 # evidently previous is the count?
      pub.set 'achievements.beastMaster', true
      $('#beastmaster-achievement-modal').modal('show')

  pub.on 'change', 'items.*', (value, previous) ->
    return if pub.get('achievements.ultimateGear')
    items = pub.get('items')
    if +items.weapon >= 6 and +items.armor >= 5 and +items.head >= 5 and +items.shield >= 5
      pub.set 'achievements.ultimateGear', true
      $('#max-gear-achievement-modal').modal('show')

  priv.on 'change', 'tasks.*.streak', (id, value, previous) ->
    if value > 0

      # 21-day streak, as per the old philosophy of doign a thing 21-days in a row makes a habit
      if (value % 21) is 0
        pub.increment 'achievements.streak', 1
        $('#streak-achievement-modal').modal('show')

      # they're undoing a task at the 21 mark, take back their badge
      else if (previous - value is 1) and (previous % 21 is 0)
        pub.increment 'achievements.streak', -1
