module.exports = (store) ->

  protectRead = (shareRequest, next) ->
    return next() unless shareRequest.collection in ["usersPrivate", "usersPublic"]
    return next() unless shareRequest.docName? and shareRequest.agent.connectSession?.userId?
    return next() if shareRequest.docName is shareRequest.agent.connectSession.userId
    return next() if shareRequest.agent.stream.isServer # FIXME for now allow ever server write to go through
    if shareRequest.agent.connectSession
      next new Error("Not allowed to fetch users who are not you.")

  ###
  Delegate to ShareJS directly to protect fetches and subscribes. Will try to
  come up with a different interface that does not expose this much of ShareJS
  to the developer using racer.
  ###
  store.shareClient.use "subscribe", protectRead
  store.shareClient.use "fetch", protectRead

  ###
  Only allow users to modify or delete themselves. Only allow the server to
  create users.
  ###
  store.onChange "usersPrivate", (docId, opData, snapshotData, session, isServer, next) ->
    if docId is (session and session.userId) then next()
    else if opData.del then next new Error("Not allowed to deleted users who are not you.")
    else if opData.create
      if isServer then next()
      else next new Error("Not allowed to create users.")
    else next new Error("Not allowed to update users who are not you.")
