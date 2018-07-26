"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
// Include necessary libraries
const os = require("os");
const azure = require("azure-storage");
const sprintf_js_1 = require("sprintf-js");
var logger;
var debug;
var flushInterval;
var hostname;
var azureQueueStats;
var service;
var queue_name;
// define a prefix for any metrics
var prefix;
var azureQueue = function (service, options) {
    options = options || {};
    this.service = service;
    this.sa_name = options.sa_name;
    this.host_name = options.host_name || os.hostname();
    this.queue_name = options.queue_name || "statsd";
    this.pending_requests = 0;
};
azureQueue.prototype.metrics = function (payload) {
    let client = this;
    let message = {
        series: payload
    };
    client._post('series', message);
};
azureQueue.prototype._post = function (controller, message) {
    let client = this;
    // set the body of the message
    let body = JSON.stringify(message);
    // incremnent the pending requests
    client.pending_requests += 1;
    // send the payload to the queue
    client.service.createQueueIfNotExists(client.queue_name, function (error) {
        if (error) {
            logger.log(sprintf_js_1.sprintf("There was a problem creating the queue: %s", client.queue_name));
        }
        else {
            logger.log(sprintf_js_1.sprintf("Queue exists: %s", client.queue_name));
        }
    });
    client.service.createMessage(client.queue_name, body, function (error) {
        if (error) {
            logger.log(sprintf_js_1.sprintf('Skipping, cannot sent data to queue: %s', error.message));
        }
        // decrement the pending requests
        client.pending_requests -= 1;
    });
};
let post_stats = function azure_queue_post_stats(payload) {
    try {
        new azureQueue(service, { queue_name: queue_name }).metrics(payload);
        azureQueueStats.last_flush = Math.round(new Date().getTime() / 1000);
    }
    catch (e) {
        if (debug) {
            logger.log(e);
        }
        azureQueueStats.last_exception = Math.round(new Date().getTime() / 1000);
    }
};
let backend_status = function azure_queue_stats(writeCb) {
    var stat;
    for (stat in azureQueueStats) {
        writeCb(null, 'azureQueue', stat, azureQueueStats[stat]);
    }
};
let flush_stats = function azure_queue_flush_stats(ts, metrics) {
    let counters = metrics.counters;
    let gauges = metrics.gauges;
    let timers = metrics.timers;
    let pctThreshold = metrics.pctThreshold;
    let host = hostname || os.hostname();
    let payload = [];
    let value;
    let key;
    // Send the counters to the remote function
    for (key in counters) {
        value = counters[key];
        // calculate the per second rate
        let valuePerSecond = value / (flushInterval / 1000);
        // create the payload object that will be the body to send to the function
        payload.push({
            metric: get_prefix(key),
            points: [[ts, valuePerSecond]],
            type: 'gauge',
            host: host
        });
    }
    // Send gauges
    for (key in gauges) {
        value = gauges[key];
        payload.push({
            metric: get_prefix(key),
            points: [[ts, value]],
            type: 'gauge',
            host: host
        });
    }
    // Compute timers and send the data
    for (key in timers) {
        if (timers[key].length > 0) {
            let values = timers[key].sort(function (a, b) { return a - b; });
            let count = values.length;
            let min = values[0];
            let max = values[count - 1];
            let mean = min;
            let maxAtThreshold = max;
            let i;
            if (count > 1) {
                let thresholdIndex = Math.round(((100 - pctThreshold) / 100) * count);
                let numInThreshold = count - thresholdIndex;
                let pctValues = values.slice(0, numInThreshold);
                maxAtThreshold = pctValues[numInThreshold - 1];
                // average the remaining timings
                let sum = 0;
                for (i = 0; i < numInThreshold; i++) {
                    sum += pctValues[i];
                }
                mean = sum / numInThreshold;
            }
            // create objects of items that need to be added to the payload
            let items = {};
            items[sprintf_js_1.sprintf("%s.mean", key)] = mean;
            items[sprintf_js_1.sprintf("%s.upper", key)] = max;
            items[sprintf_js_1.sprintf("%s.upper_%s", key, pctThreshold)] = maxAtThreshold;
            items[sprintf_js_1.sprintf("%s.lower", key)] = min;
            items[sprintf_js_1.sprintf("%s.count", key)] = count;
            for (let name in items) {
                payload.push({
                    metric: name,
                    points: [[ts, items[name]]],
                    type: 'gauge',
                    host: host
                });
            }
        }
    }
    // post the payload to the function
    post_stats(payload);
};
/**
 * Add a prefix to the metric if one has been set
 */
let get_prefix = function azure_queue_get_prefix(key) {
    if (prefix !== undefined) {
        return [prefix, key].join(".");
    }
    else {
        return key;
    }
};
// export the init function for statsd to call
exports.init = function azure_queue_init(startup_time, config, events, log) {
    // set properties
    logger = log;
    debug = config.debug;
    hostname = config.hostname;
    flushInterval = config.flushInterval;
    azureQueueStats = {};
    azureQueueStats.last_flush = startup_time;
    azureQueueStats.last_exception = startup_time;
    // create queue service
    queue_name = config.queueName;
    service = azure.createQueueService(config.storageAccountName, config.storageAccountKey);
    service.messageEncoder = new azure.QueueMessageEncoder.TextBase64QueueMessageEncoder();
    logger.log(sprintf_js_1.sprintf("Stats Queue: %s", queue_name));
    // set the events
    events.on('flush', flush_stats);
    events.on('status', backend_status);
    return true;
};
