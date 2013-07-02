_ = require 'lodash'
{items, helpers} = require 'habitrpg-shared'
{ randomVal } = helpers
{ pets, hatchingPotions } = items.items

###
  app exports
###
module.exports.app = (app) ->
  {model} = app

  app.fn
    pets:

      ###
        Choose Egg
      ###
      chooseEgg: (e, el) ->
        @model.ref '_page.pets.hatchEgg', e.at()

      ###
        Hatch Egg
      ###
      hatchEgg: (e, el) ->
        hatchingPotionName = $(el).children('select').val()
        myHatchingPotion = @pub.get 'items.hatchingPotions'
        egg = @model.get '_page.pets.hatchEgg'
        eggs = @pub.get 'items.eggs'
        myPets = @pub.get 'items.pets'

        hatchingPotionIdx = myHatchingPotion.indexOf hatchingPotionName
        eggIdx = eggs.indexOf egg

        return alert "You don't own that hatching potion yet, complete more tasks!" if hatchingPotionIdx is -1
        return alert "You don't own that egg yet, complete more tasks!" if eggIdx is -1
        return alert "You already have that pet, hatch a different combo." if myPets and myPets.indexOf("#{egg.name}-#{hatchingPotionName}") != -1

        @pub.push 'items.pets', egg.name + '-' + hatchingPotionName, =>
          eggs.splice eggIdx, 1
          myHatchingPotion.splice hatchingPotionIdx, 1
          @pub.set 'items.eggs', eggs
          @pub.set 'items.hatchingPotions', myHatchingPotion

        alert 'Your egg hatched! Visit your stable to equip your pet.'

        #FIXME Bug: this removes from the array properly in the browser, but on refresh is has removed all items from the arrays
        #user.remove 'items.hatchingPotions', hatchingPotionIdx, 1
        #user.remove 'items.eggs', eggIdx, 1

      ###
        Choose Pet
      ###
      choosePet: (e, el, next) ->
        petStr = $(el).attr('data-pet')

        return next() if @pub.get('items.pets').indexOf(petStr) == -1
        # If user's pet is already active, deselect it
        return @pub.set 'items.currentPet', {} if @pub.get('items.currentPet.str') is petStr

        [name, modifier] = petStr.split('-')
        pet = _.find pets, {name: name}
        pet.modifier = modifier
        pet.str = petStr
        @pub.set 'items.currentPet', pet

      ###
        Buy hatching potion
      ###
      buyHatchingPotion: (e, el) ->
        name = $(el).attr 'data-hatchingPotion'
        newHatchingPotion = _.find hatchingPotions, {name: name}
        gems = @priv.get('balance') * 4
        if gems >= newHatchingPotion.value
          if confirm "Buy this hatching potion with #{newHatchingPotion.value} of your #{gems} Gems?"
            @pub.push 'items.hatchingPotions', newHatchingPotion.name
            @priv.set 'balance', (gems - newHatchingPotion.value) / 4
        else
          $('#more-gems-modal').modal 'show'

      ###
        Buy Egg
      ###
      buyEgg: (e, el) ->
        name = $(el).attr 'data-egg'
        newEgg = _.find pets, {name: name}
        gems = @priv.get('balance') * 4
        if gems >= newEgg.value
          if confirm "Buy this egg with #{newEgg.value} of your #{gems} Gems?"
            @pub.push 'items.eggs', newEgg
            @priv.set 'balance', (gems - newEgg.value) / 4
        else
          $('#more-gems-modal').modal 'show'
