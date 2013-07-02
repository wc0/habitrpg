_ = require 'lodash'

module.exports.app = (app) ->
  {model} = app

  app.fn
    filters:
      toggleFilterByTag: (e, el) ->
        tagId = $(el).attr('data-tag-id')
        path = 'filters.' + tagId
        @priv.set path, !(@priv.get path)

      createTag: ->
        @priv.setNull 'tags', []
        @priv.push 'tags', {id: model.id(), name: model.get("_page.new.tag")}
        model.set '_page.new.tag', ''

      toggleEditingTags: ->
        model.set '_page.editing.tags', !model.get('_page.editing.tags')

      clearFilters: ->
        @priv.set 'filters', {}

      deleteTag: (e, el) ->
        tags = @priv.get('tags')
        tag = @priv.at "tags.#{$(el).attr('data-index')}"
        tagId = tag.get('id')

        #something got corrupted, let's clear the corrupt tags
        unless tagId
          @priv.set 'tags', _.filter( tags, ((t)-> t?.id) )
          @priv.set 'filters', {}
          return

        @priv.del "filters.#{tagId}"
        tag.remove()

        # remove tag from all tasks
        _.each @priv.get("tasks"), (task) => @priv.del "tasks.#{task.id}.tags.#{tagId}"; true

