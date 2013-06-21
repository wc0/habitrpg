_ = require 'lodash'
u = require './user.coffee'

module.exports.app = (app, model) ->
  user = u.userAts(model)

  app.fn 'toggleFilterByTag', (e, el) ->
    tagId = $(el).attr('data-tag-id')
    path = 'filters.' + tagId
    user.priv.set path, !(user.priv.get path)

  app.fn 'filtersNewTag', ->
    user.priv.setNull 'tags', []
    user.priv.push 'tags', {id: model.id(), name: model.get("_page.new.tag")}
    model.set '_page.new.tag', ''

  app.fn 'toggleEditingTags', ->
    model.set '_page.editing.tags', !model.get('_page.editing.tags')

  app.fn 'clearFilters', ->
    user.priv.set 'filters', {}

  app.fn 'filtersDeleteTag', (e, el) ->
    tags = user.priv.get('tags')
    tag = user.priv.at "tags.#{$(el).attr('data-index')}"
    tagId = tag.get('id')

    #something got corrupted, let's clear the corrupt tags
    unless tagId
      user.priv.set 'tags', _.filter( tags, ((t)-> t?.id) )
      user.priv.set 'filters', {}
      return

    user.priv.del "filters.#{tagId}"
    tag.remove()

    # remove tag from all tasks
    _.each user.priv.get("tasks"), (task) -> user.priv.del "tasks.#{task.id}.tags.#{tagId}"; true

