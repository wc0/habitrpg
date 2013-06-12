db.groups.update({}, {
    $set: {
        ids: {challenges:[], habits: [], dailys: [], todos: [], rewards: []}
    }
}, {multi:1});

