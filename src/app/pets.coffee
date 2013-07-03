_ = require 'lodash'
{items, helpers} = require 'habitrpg-shared'

###
  app exports
###
module.exports.app = (app) ->

  initDraggable = (model) ->
    myItems = model.at('_page.user.pub.items')
    $('.hatching-potion-draggable').draggable()
    $('.egg-droppable').droppable
      revert: 'invalid'
      accept: ".hatching-potion-draggable"
      activeClass: "ui-state-hover"
      hoverClass: "ui-state-active"
      drop: ( event, ui ) ->
        [eggIdx, potIdx] = [$(event.target).attr('data-index'), $(ui.draggable[0]).attr('data-index')]
        potion = myItems.get "hatchingPotions.#{potIdx}"
        egg = myItems.get "eggs.#{eggIdx}"
        pets = myItems.get "pets"

        if pets and ~pets.indexOf("#{egg.name}-#{potion}")
          return model.set("_page.errors.inventory", "You already have that pet, hatch a different combo.")
        return unless confirm("Hatch a(n) #{potion} #{egg.name}?") is true

        myItems.push 'pets', "#{egg.name}-#{potion}", ->
          myItems.remove "eggs", eggIdx, 1
          myItems.remove "hatchingPotions", potIdx, 1
          model.set "_page.errors.stable", "Your egg hatched! Select your pet from the stables."
          model.set "_page.active.tabs.options", "stable"
#          $(event.target).remove(); $(ui.draggable[0]).remove()
          app.browser.resetDom()

  app.model.on 'insert', '_page.user.pub.items.hatchingPotions', ->initDraggable(app.model)
  app.model.on 'insert', '_page.user.pub.items.eggs', ->initDraggable(app.model)
  app.on 'render', ->initDraggable(app.model)

  app.fn
    pets:

      ###
        Choose Pet
      ###
      choosePet: (e, el, next) ->
        petStr = $(el).attr('data-pet')

        return next() unless ~@pub.get('items.pets').indexOf(petStr)
        # If user's pet is already active, deselect it
        return @pub.set 'items.currentPet', {} if @pub.get('items.currentPet.str') is petStr

        [name, modifier] = petStr.split('-')
        pet = _.find items.items.pets, {name}
        pet.modifier = modifier
        pet.str = petStr
        @pub.set 'items.currentPet', pet

      ###
        Buy hatching potion
      ###
      buyHatchingPotion: (e, el) ->
        name = $(el).attr 'data-hatchingPotion'
        newHatchingPotion = _.find items.items.hatchingPotions, {name: name}
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
        newEgg = _.find items.items.pets, {name}
        gems = @priv.get('balance') * 4
        if gems >= newEgg.value
          if confirm "Buy this egg with #{newEgg.value} of your #{gems} Gems?"
            @pub.push 'items.eggs', newEgg
            @priv.set 'balance', (gems - newEgg.value) / 4
        else
          $('#more-gems-modal').modal 'show'
