db.groups.update({_id:"habitrpg"}, {
    chat: [],
    leader: "9",
    name: "HabitRPG",
    type: "guild"
}, {$upsert:true});
