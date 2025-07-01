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

cq is reserved for control-q configuration: 

```
"cq": {
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

An rdb can subscribe to multiple tickerplants. All tp's must be configured in cqconfig.json.
For each distinct group, specified as grp in subs below, the rdb will initially subscribe to the tickerplant with the lowest priority value. If that tickerplant disconnects, it will then attempt to the tickerplant with the next lowest priority value. If all fail, it will pick the one with the earliest failure time.

```
 "<rdb process name, e.g., rdb1>": {
    "host":...,
    "port":...,
    "init":"cqrdb.q",  
    "rdbconfig":{
        "dataduration":"10:00:00.000", > how long to keep data in the rdb
        "subs":[{"tp":"tp1", "grp":0, "priority":0, "tbls":["trade", "quote"], "syms":["a,b,c"]}, > subscribe to tables trade and quote for symbols a, b and c from tp1
                {"tp":"tp2", "grp":0, "priority":1, "tbls":["trade", "quote"], "syms":["a,b,c"]}, > subscribe to tables trade and quote for symbols a, b and c from tp2 (failover, tp1 is primary)
                {"tp":"tp1", "grp":1, "priority":0, "tbls":["order", "execution"], "syms":[""]}, > subscribe to table quote for all symbols from tp1 (primary)
                {"tp":"tp2", "grp":1, "priority":1, "tbls":["order", "execution"], "syms":[""]}, > subscribe to table quote for all symbols from tp2 (failover, tp1 is primary)
                {"tp":"tp3", "grp":1, "priority":2, "tbls":["order", "execution"], "syms":[""]}  > subscribe to table quote for all symbols from tp3 (failover if both tp1 and tp2 disconnect)
            ]
    }      
 }
 ```



