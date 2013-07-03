{helpers, algos} = require "habitrpg-shared"
_ = require 'lodash'

#TODO put this in habitrpg-shared
###
  We can't always use refLists, but we often still need to get a positional path by id: eg, users.1234.tasks.5678.value
  For arrays (which use indexes, not id-paths), here's a helper function so we can run indexedPath('users',:user.id,'tasks',:task.id,'value)
###
indexedPath = ->
  _.reduce arguments, (m,v) =>
    return v if !m #first iteration
    return "#{m}.#{v}" if _.isString v #string paths
    return "#{m}." + _.findIndex(@model.get(m),v)
  , ''

indexedAt = ->
  path = indexedPath(@,arguments)
  return undefined unless model.at(path).get()?
  return model.at(path)

taskInChallenge = (task) ->
  return undefined unless task?.challenge
  @model.at "groups.#{task.group.id}.challenges.#{task.challenge}.tasks.#{task.id}"

module.exports = (view) ->
  #misc
  view.fn "percent", (x, y) ->
    x=1 if x < 1
    Math.round(x/y*100)
  view.fn 'indexOf', (str1, str2) ->
    return false unless str1 && str2
    str1.indexOf(str2) != -1
  view.fn "round", Math.round
  view.fn "floor", Math.floor
  view.fn "ceil", Math.ceil
  view.fn "mod", (a, b) -> +a % +b == 0
  view.fn "notEqual", (a, b) -> (a != b)
  view.fn "truarr", (num) -> num-1
  view.fn 'count', (arr) -> arr?.length or 0
  view.fn 'int',
    get: (num) -> num
    set: (num) -> [+num]
  view.fn 'indexedPath', indexedPath

  ## Added to Derby core
  #  view.fn "lt", (a, b) -> a < b
  #  view.fn 'gt', (a, b) -> a > b
  #  view.fn "and", -> _.reduce arguments, (cumm, curr) -> cumm && curr
  #  view.fn "or", -> _.reduce arguments, (cumm, curr) -> cumm || curr

  #iCal
  view.fn "encodeiCalLink", helpers.encodeiCalLink

  #User
  view.fn "gems", (balance) -> balance * 4
  view.fn "username", (name) -> name or 'Anonymous'
  view.fn "tnl", algos.tnl
  view.fn 'equipped', helpers.equipped
  view.fn "gold", helpers.gold
  view.fn "silver", helpers.silver

  #Stats
  view.fn 'userStr', helpers.userStr
  view.fn 'totalStr', helpers.totalStr
  view.fn 'userDef', helpers.userDef
  view.fn 'totalDef', helpers.totalDef
  view.fn 'itemText', helpers.itemText
  view.fn 'itemStat', helpers.itemStat

  #Pets
  view.fn 'ownsPet', helpers.ownsPet

  #Tasks
  view.fn 'taskClasses', helpers.taskClasses

  #Chat
  view.fn 'friendlyTimestamp',helpers.friendlyTimestamp
  view.fn 'newChatMessages', helpers.newChatMessages
  view.fn 'relativeDate', helpers.relativeDate

  #Tags
  view.fn 'noTags', helpers.noTags
  view.fn 'appliedTags', helpers.appliedTags

  #Challenges
  view.fn 'taskInChallenge', (task) ->
    task?.challenge and taskInChallenge.call(@,task)?.get()
  view.fn 'taskAttrFromChallenge', (task, attr) ->
    taskInChallenge.call(@,task)?.get(attr)
  view.fn 'brokenChallengeLink', (task) ->
    task?.challenge and !(taskInChallenge.call(@,task)?.get())

  view.fn 'challengeMemberScore', (member, task) ->
    return unless member
    Math.round(member["#{task.type}s"]?[task.id]?.value) || 0

  view.fn 'activeTab', (currActive, tab, isDefault) ->
    'active' if (currActive is tab) or (!currActive and isDefault)
