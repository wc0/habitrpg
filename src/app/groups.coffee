_ = require('lodash')
{helpers} = require('habitrpg-shared')

module.exports.app = (app) ->

  currentTime = app.model.at '_page.currentTime'
  currentTime.setNull +new Date
  # Every 60 seconds, reset the current time so that the chat can update relative times
  setInterval (->currentTime.set +new Date), 60000

  ###
    Re-init tooltips when people chat
  ###
  app.model.on 'insert', '_page.party.chat', -> $('.chat-message').tooltip()
  app.model.on 'insert', '_page.tavern.chat', -> $('.chat-message').tooltip()

  ###
    App Functions
  ###
  joinGroup = (gid) ->
    $group = @model.at "groups.#{gid}"
    $group.fetch (err) => $group.push("members", @uid, ->location.reload())

  app.fn
    groups:

      ###
        Create
      ###
      create: (e,el) ->
        {model} = @

        # count for async purposes - allows us to run multiple racer async ops, and only reload once they're all done
        count = 1
        done = -> location.reload() if (--count is 0)

        # Preen empty groups, this way we don't need a migration script to cleanup groups
        $empty = model.query "groups", {type: 'party', members: $size: 0}
        $empty.fetch (err) ->
          console.error(err) if err
          empties = $empty.get()
          count += (empties.length or 0)
          _.each empties, ((empty) ->model.del("groups.#{empty.id}", done); true)

        type = $(el).attr('data-type')
        newGroup =
          name: model.get("_page.new.group.name")
          description: model.get("_page.new.group.description")
          leader: @uid
          members: [@uid]
          type: type
          ids: {challenges: []}
          challenges: {}

        # parties - free
        if type is 'party'
          return model.add 'groups', newGroup, done

        # guilds - 4G
        unless @priv.get('balance') >= 1
          return $('#more-gems-modal').modal 'show'
        if confirm "Create Guild for 4 Gems?"
          newGroup.privacy = (model.get("_page.new.group.privacy") || 'public') if type is 'guild'
          newGroup.balance = 1 # they spent $ to open the guild, it goes into their guild bank
          model.add 'groups', newGroup, =>
            @priv.increment 'balance', -1, done

      ###
        Toggle Edit
      ###
      toggleEdit: (e, el) ->
        path = "_page.editing.groups.#{$(el).attr('data-gid')}"
        @model.set path, !@model.get(path)

      ###
        Toggle Leader Message Edit
      ###
      toggleLeaderMessageEdit: (e, el) ->
        path = "_page.editing.leaderMessage.#{$(el).attr('data-gid')}"
        @model.set path, !@model.get(path)

      ###
        Add Website
      ###
      addWebsite: (e, el) ->
        model = @model
        e.at().unshift 'websites', model.get('_page.new.groupWebsite'), ->
          model.del '_page.new.groupWebsite'

      ###
        Invite
      ###
      invite: (e,el) ->
        model = @model
        uid = model.get('_page.new.groupInvite').replace(/[\s"]/g, '')
        model.set '_page.new.groupInvite', ''
        return if _.isEmpty(uid)

        $user = model.at "usersPublic.#{uid}"
        $user.fetch (err) ->
          throw err if err
          profile = $user.get()
          return model.set("_page.errors.group", "User with id #{uid} not found.") unless profile

          $groups = model.query 'groups', {members: $in: [uid]}
          $groups.fetch (err) ->
            throw err if err
            [group, groups] = [e.get(), $groups.get()]
            {type, name} = group; gid = group.id
            groupError = (msg) -> model.set("_page.errors.group", msg)
            invite = ->
              $.bootstrapGrowl "Invitation Sent."
              switch type
                when 'guild' then $user.push "invitations.guilds", {id:gid, name}, ->location.reload()
                when 'party' then $user.set "invitations.party", {id:gid, name}, ->location.reload()

            switch type
              when 'guild'
                if profile.invitations?.guilds and _.find(profile.invitations.guilds, {id:gid})
                  return groupError("User already invited to that group")
                else if uid in group.members
                  return groupError("User already in that group")
                else invite()
              when 'party'
                if profile.invitations?.party
                  return groupError("User already pending invitation.")
                else if _.find(groups, {type:'party'})
                  return groupError("User already in a party.")
                else invite()

      ###
        Join Group
      ###
      joinGroup: (e, el) -> joinGroup.call(@, e.get('id'))

      ###
        Accept Inivitation
      ###
      acceptInvitation: (e,el) ->
        gid = e.get('id')
        if $(el).attr('data-type') is 'party'
          @pub.set 'invitations.party', null, =>joinGroup.call(@, gid)
        else
          e.at().remove =>joinGroup.call(@, gid)

      ###
        Reject Inviation
      ###
      rejectInvitation: (e, el) ->
        clear = -> app.resetDom()
        if e.at().path().indexOf('party') != -1
          @model.del e.at().path(), clear
        else e.at().remove clear

      ###
        Group leave
      ###
      leave: (e,el) ->
        {model, uid} = @
        if confirm("Leave this group, are you sure?") is true
          group = model.at "groups.#{$(el).attr('data-id')}"
          index = group.get('members').indexOf(uid)
          if index != -1
            group.remove 'members', index, 1, ->
              updated = group.get()
              # last member out, delete the party
              if _.isEmpty(updated.members) and (updated.type is 'party')
                group.del ->location.reload()
              # assign new leader, so the party is editable #TODO allow old leader to assign new leader, this is just random
              else if (updated.leader is uid)
                group.set "leader", updated.members[0], ->location.reload()
              else location.reload()

      ###
          Assign new leader
      ###
      assignLeader: (e, el) ->
        newLeader = @model.get('_page.new.groupLeader')
        if newLeader and (confirm("Assign new leader, you sure?") is true)
          e.at().set('leader', newLeader, ->app.resetDom()) if newLeader