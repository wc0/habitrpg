db.users.find({}).forEach(function(user){

    user.ids = {};
    ['habit','daily','todo','reward'].forEach(function(type){
        user.ids[type] = user[type + 'Ids'];
        delete user[type + 'Ids'];
    });

    db.users.update({_id: user._id}, {
        $set: { ids: ids },
        $unset: { habitIds: 1, dailyIds: 1, todoIds: 1, rewardIds: 1 }
    })
})