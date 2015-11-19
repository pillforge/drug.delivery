/*globals define*/
/*jshint node:true, browser:true*/

/**
 * Generated by PluginGenerator 0.14.0 from webgme on Tue Oct 27 2015 13:49:24 GMT-0500 (CDT).
 */

define([
  'plugin/PluginConfig',
  'plugin/PluginBase',
  'module'
], function (
  PluginConfig,
  PluginBase,
  module) {
  'use strict';

  /**
   * Initializes a new instance of DrugDelivery.
   * @class
   * @augments {PluginBase}
   * @classdesc This class represents the plugin DrugDelivery.
   * @constructor
   */
  var DrugDelivery = function () {
    // Call base class' constructor.
    PluginBase.call(this);
  };

  // Prototypal inheritance from PluginBase.
  DrugDelivery.prototype = Object.create(PluginBase.prototype);
  DrugDelivery.prototype.constructor = DrugDelivery;

  /**
   * Gets the name of the DrugDelivery.
   * @returns {string} The name of the plugin.
   * @public
   */
  DrugDelivery.prototype.getName = function () {
    return 'DrugDelivery';
  };

  /**
   * Gets the semantic version (semver.org) of the DrugDelivery.
   * @returns {string} The version of the plugin.
   * @public
   */
  DrugDelivery.prototype.getVersion = function () {
    return '0.1.0';
  };

  /**
   * Main function for the plugin to execute. This will perform the execution.
   * Notes:
   * - Always log with the provided logger.[error,warning,info,debug].
   * - Do NOT put any user interaction logic UI, etc. inside this method.
   * - callback always has to be called even if error happened.
   *
   * @param {function(string, plugin.PluginResult)} callback - the result callback
   */
  DrugDelivery.prototype.main = function (callback) {
    var self = this;
    var nodeObject = self.activeNode;

    var meta_types = ['app', 'uses', 'schedule', 'input', 'time', 'start', 'template_app'];
    var meta_complete = meta_types.every(function(e) {
      return self.META[e];
    });
    if (!meta_complete) {
      return callback('META definition is not complete', self.result);
    }

    if (!self.core.isTypeOf(nodeObject, self.META.app) ) {
      return callback('Object is not an *app*', self.result);
    }

    self.template_apps_data = {
      'DrugDeliveryBase': {
        filename: 'schedule_data.h',
        schedule: {
          type: 'schedule',
          name: 'schedule_data_macro'
        },
        viscosity: {
          type: 'number',
          name: 'viscosity'
        },
        viscosity_a: {
          type: 'number',
          name: 'viscosity_a'
        },
        viscosity_b: {
          type: 'number',
          name: 'viscosity_b'
        }
      },
      'DrugDeliveryMCR': {
        filename: 'drug_delivery_mcr.h',
        heartbeat: {
          type: 'number',
          name: 'heartbeat'
        }
      }
    };

    self.compileAny(nodeObject, function (err, results) {
      if (err) {
        return callback(err, self.result);
      }
      self.result.setSuccess(true);
      return callback(null, self.result);
    });

  };

  DrugDelivery.prototype.compileAny = function(nodeObject, callback) {
    var self = this;
    var async = require('async');
    var path = require('path');
    var fs = require('fs');
    var dirname = module.uri;
    var template_app_name, path_to_template, radio_address;
    async.waterfall([
      function (callback) {
        self.getChildrenObj(nodeObject, callback);
      },
      function (children_obj, callback) {
        if (children_obj.template_app.length != 1) {
          return callback('There should be only 1 template_app in the sheet');
        }
        var p_node = self.core.getBase(children_obj.template_app[0]);
        radio_address = self.core.getAttribute(children_obj.template_app[0], 'radio_address');
        template_app_name = self.core.getAttribute(p_node, 'name');
        path_to_template = path.join(path.resolve(dirname), '../../../templates', template_app_name);
        if (!fs.existsSync(path_to_template)) {
          return callback('no template for ' + parent_name);
        }
        self.getInputValues(children_obj, template_app_name, callback);
      },
      function (input_obj, callback) {
        self.saveHeader(input_obj, path_to_template, template_app_name);
        self.compileAddArtifacts(path_to_template, radio_address, callback);
      }
    ],
    function (err, results) {
      if (err) {
        return callback(err);
      }
      callback();
    });
  };

  DrugDelivery.prototype.getChildrenObj = function(nodeObject, callback) {
    var self = this;
    var result = {
      'template_app': [],
      'uses': []
    };
    self.core.loadChildren(nodeObject, function (err, children) {
      if (err) {
        return callback(err);
      }
      for (var i = children.length - 1; i >= 0; i--) {
        if (self.core.isTypeOf(children[i], self.META.template_app)) {
          result.template_app.push(children[i]);
        } else if (self.core.isTypeOf(children[i], self.META.uses)) {
          result.uses.push(children[i]);
        }
      }
      return callback(null, result);
    });
  };

  DrugDelivery.prototype.getInputValues = function (children_obj, appname, callback) {
    var self = this;
    var async = require('async');
    var macro_obj = {};
    async.each(children_obj.uses, function (uses, callback) {
      async.parallel([
        function (callback) {
          self.core.loadPointer(uses, 'src', callback);
        },
        function (callback) {
          self.core.loadPointer(uses, 'dst', callback);
        }
      ], function (err, results) {
        var src_obj = results[0];
        var dst_obj = results[1];
        var dst_name = self.core.getAttribute(dst_obj, 'name');

        if (self.template_apps_data[appname][dst_name].type == 'schedule') {
          self.getSchedule(src_obj, function (err, schedule) {
            if (err) {
              return callback(err);
            }
            macro_obj[dst_name] = self.scheduleToString(schedule);
            callback();
          });
        } else if (dst_name == 'viscosity') {
          var src_val = self.core.getAttribute(src_obj, 'value');
          if (src_val.indexOf('.') > -1) {
            var visc_val_arr = src_val.split('.');
            macro_obj.viscosity_a = visc_val_arr[0];
            macro_obj.viscosity_b = visc_val_arr[1];
          } else {
            macro_obj.viscosity_a = src_val;
            macro_obj.viscosity_b = 0;
          }
          callback();
        } else {
          var src_value = self.core.getAttribute(src_obj, 'value');
          macro_obj[dst_name] = src_value;
          callback();
        }

      });
    }, function (err) {
      if (err) {
        return callback(err);
      }
      callback(null, macro_obj);
    });
  };

  DrugDelivery.prototype.scheduleToString = function(schedule_data) {
    return '{' + schedule_data.map(function (sch) {
      return '{' + sch[0] + ', ' + sch[1] + '}';
    }).join(', ') + '}';
  };

  DrugDelivery.prototype.compileAddArtifacts = function(path_to_template, radio_address, callback) {
    var self = this;
    var path = require('path');
    var fs = require('fs');
    var execSync = require('child_process').execSync;
    var cmd = 'make exp430 install.' + radio_address;
    try {
      execSync(cmd, {
        cwd: path_to_template,
        stdio: 'inherit'
      });
    } catch (err) {
      return callback(err);
    }
    var artifact = self.blobClient.createArtifact(path.basename(path_to_template));
    var path_to_build = path.join(path_to_template, 'build', 'exp430');
    var files = fs.readdirSync(path_to_build);
    var filesToAdd = {};
    files.forEach(function(file) {
      filesToAdd[file] = fs.readFileSync(path.join(path_to_build, file));
    });
    artifact.addFiles(filesToAdd, function (err, hashes) {
      artifact.save(function (err, hash) {
        self.result.addArtifact(hash);
        callback();
      });
    });
  };

  DrugDelivery.prototype.saveHeader = function(macro_obj, file_path, appname) {
    var path = require('path');
    var fs = require('fs');
    var d = this.template_apps_data[appname];
    file_path = path.join(file_path, d.filename);
    var s = '';
    for (var mac in macro_obj) {
      s += '#define ' + d[mac].name + ' ' + macro_obj[mac] + '\n';
    }
    fs.writeFileSync(file_path, s);
  };


  DrugDelivery.prototype.getSchedule = function (schedule_obj, callback) {
    var self = this;
    var cache = {};
    var order = {};
    var schedule = [];
    var initial, duration, amount;
    self.core.loadChildren(schedule_obj, function (err, children) {
      for (var i = children.length - 1; i >= 0; i--) {
        var path = self.core.getPath(children[i]);
        cache[path] = children[i];
      }
      for (i = children.length - 1; i >= 0; i--) {
        if (self.core.isTypeOf(children[i], self.META.time)) {
          var src = self.core.getPointerPath(children[i], 'src');
          var dst = self.core.getPointerPath(children[i], 'dst');
          duration = self.core.getAttribute(children[i], 'duration');
          amount = self.core.getAttribute(cache[dst], 'amount');
          order[src] = [dst, duration, amount];
        } else if (self.core.isTypeOf(children[i], self.META.start)) {
          initial = self.core.getPath(children[i]);
        }
        // else if (self.core.isTypeOf(children[i], self.META.release)) {
        // } else if (self.core.isTypeOf(children[i], self.META.end)) {
        // }
      }

      var curr = initial;
      while (order.hasOwnProperty(curr)) {
        duration = order[curr][1];
        amount = order[curr][2];
        curr = order[curr][0];
        if (amount) {
          schedule.push([duration, amount]);
        }
      }
      callback(null, schedule);
    });
  };

  return DrugDelivery;
});
