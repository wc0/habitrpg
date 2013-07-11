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
    // We're getting false positives without this super-explicit check
    if (user.flags.rest === true) user.preferences.resting = true;

    // Give them their default display name
    if ( !user.profile || !user.profile.name ) {
        if (!user.profile) user.profile = {};
        if (!!user.auth.facebook) {
            if (!!user.auth.facebook.displayName) {
                user.profile.name = user.auth.facebook.displayName;
            } else {
                var fb = user.auth.facebook;
                user.profile.name = !!fb._raw ? fb.name.givenName + " " + fb.name.familyName : fb.name;
            }
        } else {
            try {
                user.profile.name = user.auth.local.username;
            } catch (err) {
                printjson(user.auth);
            }
        }
    }

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

// FIXME this should be in derby-auth, but it's throwing errors when performed via mongoskin
db.auths.ensureIndex( { 'facebook.id': 1 }, {background: true} )
db.auths.ensureIndex( { 'local.username': 1 }, {background: true} )
db.auths.ensureIndex( { 'local.username': 1, 'local.hashed_password': 1 }, {background: true} )