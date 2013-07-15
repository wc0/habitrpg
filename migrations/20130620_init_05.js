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
    var uid = user._id,
        auth = user.auth,
        priv = {},
        pub = {};

    auth._id = uid;

    user.ids = {};
    ['habit','daily','todo','reward'].forEach(function(type){
        user.ids[type + 's'] = user[type + 'Ids'];
    });

    // Migrate "rest" flag to preferences (so it's public)
    // We're getting false positives without this super-explicit check
    if (user.flags && user.flags.rest === true) user.preferences.resting = true;

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
            user.profile.name = user.auth.local.username;
        }
    }

    user.tasks = _.transform(user.tasks, function(acc,v,k,obj) {
        if (!!k && !_.contains(_.keys(v),'$spec')) acc[k] = v;
    })

    user.flags.newStuff = 'show';

    [   '_id',
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

    [    '_id',
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
    });

    try {
        db.auths.insert(auth);
        db.usersPrivate.insert(priv);
        db.usersPublic.insert(pub);
        db.users.remove({_id: uid});
    } catch (err) {
        printjson({error: uid});
    }

})

// Add indices
db.usersPrivate.ensureIndex( { _id: 1, apiToken: 1 }, {background: true} )
db.groups.ensureIndex( { members: 1 }, {background: true} )
db.groups.ensureIndex( { type: 1 }, {background: true} )
db.groups.ensureIndex( { type: 1, privacy: 1 }, {background: true} )

// FIXME this should be in derby-auth, but it's throwing errors when performed via mongoskin
db.auths.ensureIndex( { 'facebook.id': 1 }, {background: true} )
db.auths.ensureIndex( { 'local.username': 1 }, {background: true} )
db.auths.ensureIndex( { 'local.username': 1, 'local.hashed_password': 1 }, {background: true} )