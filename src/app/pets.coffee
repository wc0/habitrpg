_ = require 'lodash'
{items, helpers} = require 'habitrpg-shared'
{ randomVal } = helpers
{ pets, hatchingPotions } = items.items
u = require './user.coffee'

###
  app exports
###
module.exports.app = (app) ->
  {model} = app
  user = u.userAts(model)

  app.fn 'chooseEgg', (e, el) ->
    model.ref '_page.hatchEgg', e.at()

  app.fn 'hatchEgg', (e, el) ->
    hatchingPotionName = $(el).children('select').val()
    myHatchingPotion = user.pub.get 'items.hatchingPotions'
    egg = model.get '_page.hatchEgg'
    eggs = user.pub.get 'items.eggs'
    myPets = user.pub.get 'items.pets'

    hatchingPotionIdx = myHatchingPotion.indexOf hatchingPotionName
    eggIdx = eggs.indexOf egg

    return alert "You don't own that hatching potion yet, complete more tasks!" if hatchingPotionIdx is -1
    return alert "You don't own that egg yet, complete more tasks!" if eggIdx is -1
    return alert "You already have that pet, hatch a different combo." if myPets and myPets.indexOf("#{egg.name}-#{hatchingPotionName}") != -1

    user.pub.push 'items.pets', egg.name + '-' + hatchingPotionName, ->
      eggs.splice eggIdx, 1
      myHatchingPotion.splice hatchingPotionIdx, 1
      user.pub.set 'items.eggs', eggs
      user.pub.set 'items.hatchingPotions', myHatchingPotion

    alert 'Your egg hatched! Visit your stable to equip your pet.'

    #FIXME Bug: this removes from the array properly in the browser, but on refresh is has removed all items from the arrays
#    user.remove 'items.hatchingPotions', hatchingPotionIdx, 1
#    user.remove 'items.eggs', eggIdx, 1

  app.fn 'choosePet', (e, el, next) ->
    petStr = $(el).attr('data-pet')

    return next() if user.pub.get('items.pets').indexOf(petStr) == -1
    # If user's pet is already active, deselect it
    return user.pub.set 'items.currentPet', {} if user.pub.get('items.currentPet.str') is petStr

    [name, modifier] = petStr.split('-')
    pet = _.find pets, {name: name}
    pet.modifier = modifier
    pet.str = petStr
    user.pub.set 'items.currentPet', pet

  app.fn 'buyHatchingPotion', (e, el) ->
    name = $(el).attr 'data-hatchingPotion'
    newHatchingPotion = _.find hatchingPotions, {name: name}
    gems = user.priv.get('balance') * 4
    if gems >= newHatchingPotion.value
      if confirm "Buy this hatching potion with #{newHatchingPotion.value} of your #{gems} Gems?"
        user.pub.push 'items.hatchingPotions', newHatchingPotion.name
        user.priv.set 'balance', (gems - newHatchingPotion.value) / 4
    else
      $('#more-gems-modal').modal 'show'

  app.fn 'buyEgg', (e, el) ->
    name = $(el).attr 'data-egg'
    newEgg = _.find pets, {name: name}
    gems = user.priv.get('balance') * 4
    if gems >= newEgg.value
      if confirm "Buy this egg with #{newEgg.value} of your #{gems} Gems?"
        user.pub.push 'items.eggs', newEgg
        user.priv.set 'balance', (gems - newEgg.value) / 4
    else
      $('#more-gems-modal').modal 'show'
