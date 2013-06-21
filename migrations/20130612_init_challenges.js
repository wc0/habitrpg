db.groups.update({}, {
    $set: {
        challenges: {},
        ids: {challenges:[]}
    }
}, {multi:1});

