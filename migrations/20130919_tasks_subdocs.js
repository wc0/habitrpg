/**
 Derby requires a strange storage format for somethign called "refLists". Here we hook into loading the data, so we
 can provide a more "expected" storage format for our various helper methods. Since the attributes are passed by reference,
 the underlying data will be modified too - so when we save back to the database, it saves it in the way Derby likes.
 This will go away after the rewrite is complete
 */
db.users.find().forEach(function(user){
  _.each(['habit', 'daily', 'todo', 'reward'], function(type) {
    // we use _.transform instead of a simple _.where in order to maintain sort-order
    user[type + "s"] = _.reduce(user[type + "Ids"], function(m, tid) {
      if (!user.tasks[tid]) return m; // tmp hotfix, people still have null tasks?
      if (!user.tasks[tid].tags) user.tasks[tid].tags = {};
      m.push(user.tasks[tid]);
      return m;
    }, []);
    delete user[type + "Ids"];
  });
  db.users.save(user);
})
