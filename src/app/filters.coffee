_ = require 'lodash'

module.exports.app = (app, model) ->
  user = model.at('_session.user')

  app.fn 'toggleFilterByTag', (e, el) ->
    tagId = $(el).attr('data-tag-id')
    path = 'filters.' + tagId
    user.set path, !(user.get path)

  app.fn 'filtersNewTag', ->
    user.setNull 'tags', []
    user.push 'tags', {id: model.id(), name: model.get("_page.new.tag")}
    model.set '_page.new.tag', ''

  app.fn 'toggleEditingTags', ->
    model.set '_page.editing.tags', !model.get('_page.editing.tags')

  app.fn 'clearFilters', ->
    user.set 'filters', {}

  app.fn 'filtersDeleteTag', (e, el) ->
    tags = user.get('tags')
    tag = e.at "_session.user.tags." + $(el).attr('data-index')
    tagId = tag.get('id')

    #something got corrupted, let's clear the corrupt tags
    unless tagId
      user.set 'tags', _.filter( tags, ((t)-> t?.id) )
      user.set 'filters', {}
      return

    model.del "_session.user.filters.#{tagId}"
    tag.remove()

    # remove tag from all tasks
    _.each user.get("tasks"), (task) -> user.del "tasks.#{task.id}.tags.#{tagId}"; true

