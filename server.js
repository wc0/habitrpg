// Load nconf and define default configuration values if config.json or ENV vars are not found
var path = require('path')
    ,nconf = require('nconf')
    ,_ = require('lodash');

nconf.argv().env().file(path.join(__dirname + "/config.json")).defaults({
   'PORT': 3000,
   'IP': '0.0.0.0',
   'BASE_URL': 'http://localhost',
   'NODE_ENV': 'development'
});

/*_.each(nconf.get(), function(v,k){
    process.env[k] = v; // for any code not using nconf (eg, derby internal)
});*/

/*var agent;
if (process.env.NODE_ENV === 'development') {
    // Follow these instructions for profiling / debugging leaks
    // * https://developers.google.com/chrome-developer-tools/docs/heap-profiling
    // * https://developers.google.com/chrome-developer-tools/docs/memory-analysis-101
    agent = require('webkit-devtools-agent');
    console.log("To debug memory leaks:" +
        "\n\t(1) Run `kill -SIGUSR2 " + process.pid + "`" +
        "\n\t(2) open http://c4milo.github.com/node-webkit-agent/21.0.1180.57/inspector.html?host=localhost:1337&page=0");
}*/

process.on('uncaughtException', function (error) {
    try {
        var nodemailer = require("nodemailer");

        function sendEmail(mailData) {

            var creds = {
                service: nconf.get('SMTP_SERVICE'),
                auth: {
                    user: nconf.get('SMTP_USER'),
                    pass: nconf.get('SMTP_PASS')
                }
            };

            if (!nodemailer || !creds.service || !creds.auth.user || !creds.auth.pass) return;

            // create reusable transport method (opens pool of SMTP connections)
            var smtpTransport = nodemailer.createTransport("SMTP", creds);

            // send mail with defined transport object
            smtpTransport.sendMail(mailData, function(error, response){
                if(error){
                    console.log(error);
                }else{
                    console.log("Message sent: " + response.message);
                }

                smtpTransport.close(); // shut down the connection pool, no more messages
            });
        }

        sendEmail({
            from: "HabitRPG <admin@habitrpg.com>",
            to: "tylerrenelle@gmail.com",
            subject: "HabitRPG Error",
            text: error.stack
        });
        console.error(error.stack);

    } catch (err) {
        console.error(err)
    }
});

require('coffee-script'); // remove intermediate compilation requirement
require('derby').run(__dirname + '/src/server', nconf.get('PORT'));

/*if (nconf.get('NODE_ENV') === 'production') {
    require('derby').run(__dirname + '/src/server', nconf.get('PORT'));
} else {
    require('./src/server').listen(nconf.get('PORT'), conf.get('IP'));
}*/

// Note: removed "up" module, which is default for development (but interferes with and production + PaaS)
// Restore to 5310bb0 if I want it back (see https://github.com/codeparty/derby/issues/165#issuecomment-10405693)
