//mongo habitrpg ./node_modules/lodash/lodash.js migrations/20130620_init_05.js


// Drop some collections
db.sessions.drop();
db.myDupesCollection.drop();

var un_registered = {
        "auth.local": {$exists: false},
        "auth.facebook": {$exists: false}
    },

    registered = {
        $or: [
            { 'auth.local': { $exists: true }},
            { 'auth.facebook': { $exists: true }}
        ]
    };

// we're completely doing away with staging users. too difficult to keep up with now, with migrations being an issue, etc
db.users.remove(un_registered);

db.users.find(registered).forEach(function(user){

    user.ids = {};
    ['habit','daily','todo','reward'].forEach(function(type){
        user.ids[type + 's'] = user[type + 'Ids'];
    });

    // Migrate "rest" flag to preferences (so it's public)
    user.preferences.resting = user.flags.rest;

    user.tasks = _.transform(user.tasks, function(acc,v,k,obj) {
        if (!!k && !_.contains(_.keys(v),'$spec')) acc[k] = v;
    })

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

// Add indices
db.usersPrivate.ensureIndex( { _id: 1, apiToken: 1 }, {background: true} )