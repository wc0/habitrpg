# Turn a mongo db into a live-db
# you should probably redis-cli flushdb; before running this script

redis = require 'redis'
mongo = require 'mongoskin'
argv = require('optimist').argv
_ = require 'lodash'

mongo_host = process.env.MONGO_HOST or 'localhost'
mongo_port = process.env.MONGO_PORT or 27017
mongo_db   = argv.db or process.env.MONGO_DB or 'habitrpg'
db         = mongo.db "#{mongo_host}:#{mongo_port}/#{mongo_db}?auto_reconnect"

if process.env.REDIS_PORT and process.env.REDIS_HOST
  rc = redis.createClient(process.env.REDIS_PORT, process.env.REDIS_HOST)
else
  rc = redis.createClient()

if process.env.REDIS_AUTH
  rc.auth(process.env.REDIS_AUTH)

rc.select argv.r ? 1

ottypes = require('ottypes')
jsonType = ottypes.json0.uri

rc.on 'error', (err) ->
  console.error("redis error", err)

db.collections (err, collections) ->
  habitGuild =
    _id: "habitrpg"
    chat: []
    leader: "9"
    name: "HabitRPG"
    type: "guild"

  key = "groups.habitrpg ops"
  op = JSON.stringify create: {type: jsonType, data: habitGuild}

  rc.rpush key, op, (err) ->
    console.error err if err
    _.defaults habitGuild, {id: 'habitrpg', _v: 1, _type: jsonType}
    db.collection('groups').update {_id: "habitrpg"}, habitGuild, {upsert:true}, (err) ->
      console.error err if err
      db.close()
      process.exit()

