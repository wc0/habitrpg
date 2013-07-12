_ = require 'lodash'
{helpers} = require 'habitrpg-shared'

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
        tid = $(el).attr('data-id')
        tag = helpers.indexedAt.call @, "_page.user.priv.tags", {id: tid}

        #something got corrupted, let's clear the corrupt tags
        unless tid
          @priv.set 'tags', _.filter( @priv.get('tags'), ((t)-> t?.id) )
          @priv.set 'filters', {}
          return

        @priv.del "filters.#{tid}"
        tag.remove()

        # remove tag from all tasks
        _.each @priv.get("tasks"), (task) => @priv.del "tasks.#{task.id}.tags.#{tid}"; true

