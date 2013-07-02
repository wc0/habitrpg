_ = require 'lodash'
{helpers} = require 'habitrpg-shared'

module.exports.app = (app) ->

  app.on 'render', (ctx) ->
    self = @
    $('#party-tab-link').on 'shown', (e) ->
      messages = model.get('_page.party.chat')
      return false unless messages?.length > 0
      self.priv.set 'party.lastMessageSeen', messages[0].id

  app.fn
    chat:

      ###
        Send Message
      ###
      send: (e,el) ->
        {model} = @
        text = model.get '_page.new.chat'
        # Check for non-whitespace characters
        return unless /\S/.test text

        group = e.at()

        # get rid of duplicate member ids - this is a weird place to put it, but works for now
        members = group.get('members'); uniqMembers = _.uniq(members)
        group.set('members', uniqMembers) if !_.isEqual(uniqMembers, members)

        model.set('_page.new.chat', '')

        id = model.id()
        message =
          id: id
          uuid: @uid
          contributor: @pub.get('backer.contributor')
          npc: @pub.get('backer.npc')
          text: text
          user: helpers.username(@priv.get('auth'), @pub.get('profile.name'))
          timestamp: +new Date

        group.unshift 'chat', message, ->group.remove('chat', 200)
        type = $(el).attr('data-type')
        @priv.set 'party.lastMessageSeen', id if group.get('type') is 'party'

      ###
        Key up for same thing
      ###
      keyUp: (e, el, next) ->
        return next() unless e.keyCode is 13
        app.chat.send(e, el)

      ###
        Go to party chat
      ###
      gotoPartyChat: ->
        @model.set '_page.active.gamePane', true, ->
          $('#party-tab-link').tab('show')