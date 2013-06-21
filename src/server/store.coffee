module.exports = (store) ->

  # FIXME add in access restrictions once we've split collections
  return

  ###
  Delegate to ShareJS directly to protect fetches and subscribes. Will try to
  come up with a different interface that does not expose this much of ShareJS
  to the developer using racer.
  ###
  store.shareClient.use "subscribe", protectRead
  store.shareClient.use "fetch", protectRead

  protectRead = (shareRequest, next) ->
    return next() if shareRequest.collection isnt "users"
    return next() if shareRequest.docName is shareRequest.agent.connectSession.userId
    if shareRequest.agent.connectSession
      next new Error("Not allowed to fetch users who are not you.")

  ###
  Only allow users to modify or delete themselves. Only allow the server to
  create users.
  ###
  store.onChange "users", (docId, opData, snapshotData, session, isServer, next) ->
    if docId is (session and session.userId)
      next()
    else if opData.del
      next new Error("Not allowed to deleted users who are not you.")
    else if opData.create
      if isServer
        next()
      else
        next new Error("Not allowed to create users.")
    else
      next new Error("Not allowed to update users who are not you.")
