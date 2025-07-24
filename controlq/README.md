# Control-q

A process control, tickerplant and rdb framework.

## Setup

### 1. cqconfig.json

Set up all processes in this json file. You can specify another json file using the '--configpath'  flag on the command line

Each element in cqconfig.json is a process except for cq. Each process should have the following keys:

```
<processname>: {
        "host":"localhost",
        "port":5001,
        "init":"somefile.q"
}
```

cqagent is reserved for control-q configuration: 

```
"cqagent": {
        "logdir":"<directory for logs>",
        "logprefix":"log_",
        "logrollinterval":"12:00:00",
        "loglevel":"SILENT,DEBUG,INFO,WARN,ERROR,FATAL"
 }
```

 For other processes:



**tickerplant:**

```
 "<tp process name, e.g., tp1>": {
    "host":...,
    "port":...,
    "init":"cqtick.q",
    "tpconfig":{
        "schemafile":"schema.q",
        "tplogdir":"/data/.../tplogs",
        "tplogprefix":"tplog_",
        "tplogrollinterval":"02:00:00"
    }
 }
```
**rdb:**

An rdb can subscribe to one or more tickperplants. It can also have failover tickperplants specified by groups. Within a group, only one tickerplant is active at a time. The rdb will subscribe to the tickerplant with the lowest priority value within a group first. If that tickerplant disconnects, it will then attempt to the tickerplant with the next lowest priority value. If all fail, it will pick the one with the earliest failure time (in effect round-robinning once all tickerplants within a group have failed).

You can have multiple groups of tickerplants, e.g., one group for order and execution data, the other for market data. The rdb will subscribe to one tickerplant from each group.

For each tickerplant subscription, you can specify all tables and all syms, or a subset of both.

E.g.,

This specifies a subscription to tp_md1 for trade and quote data for selected syms:

```
{"tp":"tp_md1", "grp":0, "priority":0, "tbls":["trade", "quote"], "syms":["GOOG,MSFT,AAPL,META"]}
```

This is the same subscription but for all syms. Use init:"cqrdb.q" to initialize the rdb from within the controlq framework.

```
{"tp":"tp_md1", "grp":0, "priority":0, "tbls":["trade", "quote"], "syms":[""]}
```

And this is the same subscription but for all tables and all syms:

```
{"tp":"tp_md1", "grp":0, "priority":0, "tbls":[""], "syms":[""]}
```

This is a subscription with tp_md1 as the main tickerplant and tp_md2 as the failover tickerplant:

```
{"tp":"tp_md1", "grp":0, "priority":0, "tbls":[""], "syms":[""]},
{"tp":"tp_md2", "grp":0, "priority":1, "tbls":[""], "syms":[""]}
```

This is a full rdb configuration for an rdb process named rdb1. Use init:"cqrdb.q" to initialize the process as an rdb:

```
 "<rdb1>": {
    "host":"localhost",
    "port":5011,
    "init":"cqrdb.q",  
    "rdbconfig":{
        "dataduration":"10:00:00.000", >>> how long to keep data in the rdb
        "subs":[{"tp":"tp1", "grp":0, "priority":0, "tbls":["trade", "quote"], "syms":["a,b,c"]}, >>> subscribe to tables trade and quote for symbols a, b and c from tp1
                {"tp":"tp2", "grp":0, "priority":1, "tbls":["trade", "quote"], "syms":["a,b,c"]}, >>> subscribe to tables trade and quote for symbols a, b and c from tp2 (failover, tp1 is primary)
                {"tp":"tp1", "grp":1, "priority":0, "tbls":["order", "execution"], "syms":[""]}, >>> subscribe to table quote for all symbols from tp1 (primary)
                {"tp":"tp2", "grp":1, "priority":1, "tbls":["order", "execution"], "syms":[""]}, >>> subscribe to table quote for all symbols from tp2 (failover, tp1 is primary)
                {"tp":"tp3", "grp":1, "priority":2, "tbls":["order", "execution"], "syms":[""]}  >>> subscribe to table quote for all symbols from tp3 (failover if both tp1 and tp2 disconnect)
            ]
    }      
 }
 ```

### 2. Start the processes

First start cqagent.q

```
q cqagent.q -p 5002 -instance cqagent -agentport 5002
```

From within the agent, start/stop the processes:

```
.cq.startInstance[`tp1]
.cq.stopInstance[`tp1]

.cq.instances
....





