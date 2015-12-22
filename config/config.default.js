'use strict';

var config = require('./config.webgme'),
    validateConfig = require('webgme/config/validator');

// Add/overwrite any additional settings here
// config.server.port = 8080;
config.mongo.uri = 'mongodb://127.0.0.1:27017/multi';
config.seedProjects.defaultProject = 'DrugDeliverySeed';
config.plugin.allowServerExecution = true;
config.plugin.allowBrowserExecution = false;

validateConfig(config);
module.exports = config;