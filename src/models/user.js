var mongoose = require("mongoose");
var Schema = mongoose.Schema;
var helpers = require('habitrpg-shared/script/helpers');
var _ = require('lodash');

/**
 * Define task schemas. Note they're not Mongoose Schemas, else they'd be stored in separate collection (which we
 * don't want). Instead we define them up here, extend them with particular properties, then nest them in user.*
 */
var taskSchema = {
  _id: {type: String, 'default': helpers.uuid},
  notes: String,
  tags: {type: Schema.Types.Mixed, 'default': {}},
  text: String,
  type: {type: String, 'default': 'habit'}
  value: {type: Number, 'default': 0},
  priority: {type: String, 'default': '!'},
}

var history = [{date: Date, value: Number, 'default': Date.now}];

var habitSchema = new Schema(_.defaults({
  history: history,
  up: {type: Boolean, 'default': true},
  down: {type: Boolean, 'default': true},
  type: {type: String, 'default': 'habit'},
}, taskSchema));

var dailySchema = new Schema(_.defaults({
  history: history,
  repeat: {type: Schema.Types.Mixed, 'default': {m:1,t:1,w:1,th:1,f:1,s:1,su:1}}, // TODO verify this works
  streak: Number,
  completed: {type: Boolean, 'default': false},
  type: {type: String, 'default': 'daily'},
}, taskSchema));

var todoSchema = new Schema(_.defaults({
  type: {type: String, 'default': 'todo'},
  completed: {type: Boolean, 'default': false},
}, taskSchema));

var rewardSchema = new Schema(_.defaults({
  type: {type: String, 'default': 'reward'},
  value: {type: Number, 'default': 20},
}, taskSchema));

_.each([habitSchema, dailySchema, todoSchema, rewardSchema], function(schema){
  schema.virtual('id').get(function () { return this._id });
})

/**
 * Define user schema
 */
var UserSchema = new Schema({
  _id: {type: String, 'default': helpers.uuid},
  apiToken: {type: String, 'default': helpers.uuid},

  // We want to know *every* time an object updates. Mongoose uses __v to designate when an object contains arrays which
  // have been updated (http://goo.gl/gQLz41), but we want *every* update
  _v: {type: Number, 'default': 0},

  achievements: {
    originalUser: Boolean,
    helpedHabit: Boolean,
    ultimateGear: Boolean,
    beastMaster: Boolean,
    streak: Number
  },
  auth: {
    facebook: Schema.Types.Mixed,
    local: {
      email: String,
      hashed_password: String,
      salt: String,
      username: String
    },
    timestamps: {
      created: {type: Date, 'default': Date.now},
      loggedin: Date
    }
  },

  backer: {
    tier: Number,
    admin: Boolean,
    npc: String,
    contributor: String,
    tokensApplied: Boolean
  },

  balance: Number,
  filters: {type: Schema.Types.Mixed, 'default': {}},

  flags: {
    customizationsNotification: {type: Boolean, 'default': false},
    showTour: {type: Boolean, 'default': true},
    ads: {type: String, 'default': 'show'}, // FIXME make this a boolean, run migration
    dropsEnabled: {type: Boolean, 'default': false},
    itemsEnabled: {type: Boolean, 'default': false},
    newStuff: {type: String, 'default': 'hide'}, //FIXME to boolean (currently show/hide)
    rewrite: {type: Boolean, 'default': true},
    partyEnabled: Boolean, // FIXME do we need this?
    petsEnabled: {type: Boolean, 'default': false},
    rest: {type: Boolean, 'default': false} // fixme - change to preferences.resting once we're off derby
  },
  history: {
    exp:    [{date: Date, value: Number}],
    todos:  [{data: Date,value: Number}]
  },

  // FIXME remove?
  invitations: {
    guilds: {type: Array, 'default': []},
    party: Schema.Types.Mixed
  },
  items: {
    armor: Number,
    weapon: Number,
    head: Number,
    shield: Number,

    // FIXME - tidy this up, not the best way to store current pet
    currentPet: {
      text: String, //Cactus
      name: String, //Cactus
      value: Number, //3
      notes: String, //"Find a hatching potion to pour on this egg, and one day it will hatch into a loyal pet."
      modifier: String, //Skeleton
      str: String //Cactus-Skeleton
    },

    eggs: [{
        dialog: String, //You've found a Wolf Egg! Find a hatching potion to pour on this egg, and one day it will hatch into a loyal pet
        name: String, // Wolf
        notes: String, //Find a hatching potion to pour on this egg, and one day it will hatch into a loyal pet.
        text: String, // Wolf
        //type: String, //Egg // this is forcing mongoose to return object as "[object Object]", but I don't think this is needed anyway?
        value: Number //3
    }],
    hatchingPotions: Array, //["Base", "Skeleton",...]
    lastDrop: {
      date: {type: Date, 'default': Date.now},
      count: {type: Number, 'default': 0}
    },

    pets: Array // ["BearCub-Base", "Cactus-Base", ...]
  },

  //FIXME store as Date?
  lastCron: {type: Date, 'default': Date.now},

  // FIXME remove?
  party: {
    //party._id //FIXME make these populate docs?
    current: String, // party._id
    invitation: String, // party._id
    lastMessageSeen: String,
    leader: Boolean
  },
  preferences: {
    armorSet: String,
    dayStart: {type:Number, 'default': 0},
    gender: {type:String, 'default': 'm'},
    hair: {type:String, 'default':'blond'},
    hideHeader: {type:Boolean, 'default':false},
    showHelm: {type:Boolean, 'default':true},
    skin: {type:String, 'default':'white'},
    timezoneOffset: Number
  },
  profile: {
    blurb: String,
    imageUrl: String,
    name: String,
    websites: Array //["http://ocdevel.com" ]
  },
  stats: {
    hp: Number,
    exp: Number,
    gp: Number,
    lvl: Number
  },
  tags: [{
      // FIXME use refs?
      id: String,
      name: String
  }],

  habits: habitSchema,
  dailys: dailySchema,
  todos: todoSchema,
  reward: rewardSchema,

}, {strict: true});


UserSchema.methods.toJSON = function() {
  var doc = this.toObject();
  doc.id = doc._id;
  doc.filters = {};
  doc._tmp = this._tmp; // be sure to send down drop notifs
  return doc;
};

/**
  FIXME - since we're using special @post('init') above, we need to flag when the original path was modified.
  Custom setter/getter virtuals?
*/
UserSchema.pre('save', function(next) {
  this.markModified('tasks');
  //our own version incrementer
  this._v++;
  next();
});

userSchema.virtual('tasks').get(function () {
  return this.habits.concat(this.dailys).concat(this.todos).concat(this.rewards);
});

module.exports.schema = UserSchema;
module.exports.model = mongoose.model("User", UserSchema);