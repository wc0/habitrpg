db.users.find().forEach(function(user){

    user.ids = {};
    ['habit','daily','todo','reward'].forEach(function(type){
        user.ids[type + 's'] = user[type + 'Ids'];
    });

    var pub = {};
    [
        '_id',
        'achievements',
        'backer',       // #locked
        'invitations',  // #writeable
        'items',
        'preferences',
        'profile',
        'stats',
        'challenges'
    ].forEach(function(attr){
        pub[attr] = user[attr];
    });

    var priv = {};
    [
        '_id',
        'apiToken',
        'balance',      // #locked
        'ids',
        'filters',
        'flags',
        'history',
        'lastCron',
        'party',
        'tags',
        'tasks'
    ].forEach(function(attr){
        priv[attr] = user[attr];
    })

    var auth = user.auth;
    auth._id = user._id

    try {
        db.auths.insert(auth);
        db.usersPrivate.insert(priv);
        db.usersPublic.insert(pub);
        db.users.remove({_id: user._id});
    } catch (err) {
        printjson({error: user._id});
    }

})

// Drop some collections
db.sessions.drop();
db.myDupesCollection.drop();

// Add indices
db.usersPrivate.ensureIndex( { _id: 1, apiToken: 1 }, {background: true} )