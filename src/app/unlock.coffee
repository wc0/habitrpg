_ = require 'lodash'
{helpers, items} = require 'habitrpg-shared'
{ randomVal } = helpers
{ pets, hatchingPotions } = items.items
u = require ('./user.coffee')

###
  Listeners to enabled flags, set notifications to the user when they've unlocked features
###

module.exports.app = (app) ->
  {model} = app
  user = u.userAts(model)

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


  user.priv.on 'change', 'flags.customizationsNotification', (after, before) ->
    return if alreadyShown(before,after)
    $('.main-herobox').popover('destroy') #remove previous popovers
    html = "Click your avatar to customize your appearance."
    showPopover '.main-herobox', 'Customize Your Avatar', html, 'bottom'

  user.priv.on 'change', 'flags.itemsEnabled', (after, before) ->
    return if alreadyShown(before,after)
    html = """
           <img src='/vendor/BrowserQuest/client/img/1/chest.png' />
           Congratulations, you have unlocked the Item Store! You can now buy weapons, armor, potions, etc. Read each item's comment for more information.
           """
    showPopover 'div.rewards', 'Item Store Unlocked', html, 'left'

  user.priv.on 'change', 'flags.petsEnabled', (after, before) ->
    return if alreadyShown(before,after)
    html = """
           <img src='/img/sprites/wolf_border.png' style='width:30px;height:30px;float:left;padding-right:5px' />
           You have unlocked Pets! You can now buy pets with Gems (note, you replenish Gems with real-life money - so chose your pets wisely!)
           """
    showPopover '#rewardsTabs', 'Pets Unlocked', html, 'left'

  user.priv.on 'change', 'flags.partyEnabled', (after, before) ->
    return if alreadyShown(before,after)
    html = """
           Be social, join a party and play Habit with your friends! You'll be better at your habits with accountability partners. Click User -> Options -> Party, and follow the instructions. LFG anyone?
           """
    showPopover '.user-menu', 'Party System', html, 'bottom'

  user.priv.on 'change', 'flags.dropsEnabled', (after, before) ->
    return if alreadyShown(before,after)
    egg = randomVal pets
    user.pub.push 'items.eggs', egg

    $('#drops-enabled-modal').modal 'show'

  user.pub.on 'insert', 'items.pets', (after, before) ->
    return if user.pub.get('achievements.beastMaster')
    if before >= 90 # evidently before is the count?
      user.pub.set 'achievements.beastMaster', true
      $('#beastmaster-achievement-modal').modal('show')

  user.pub.on 'change', 'items.*', (after, before) ->
    return if user.pub.get('achievements.ultimateGear')
    items = user.pub.get('items')
    if +items.weapon >= 6 and +items.armor >= 5 and +items.head >= 5 and +items.shield >= 5
      user.pub.set 'achievements.ultimateGear', true
      $('#max-gear-achievement-modal').modal('show')

  user.priv.on 'change', 'tasks.*.streak', (id, after, before) ->
    if after > 0

      # 21-day streak, as per the old philosophy of doign a thing 21-days in a row makes a habit
      if (after % 21) is 0
        user.pub.increment 'achievements.streak', 1
        $('#streak-achievement-modal').modal('show')

      # they're undoing a task at the 21 mark, take back their badge
      else if (before - after is 1) and (before % 21 is 0)
        user.pub.increment 'achievements.streak', -1
