system "l log4q.q";

.log4q.fm:"%p %c\t%f:%m\r\n";

system "l cqtimer.q";


.cq.init:{    
    configPath:"cqconfig.json";
    args:.Q.opt .z.x;
    if [`configpath in key args; if [0<count args`configpath; configPath:args`configpath]];
    .cq.allconf:@[read0;hsym `$configPath;{'"Unable to find ",configPath," - ",x}];
    .cq.allconf:@[.j.k; raze .cq.allconf;{'"Unable to parse ",configPath," - ",x}];
    .cq.initLogging[.cq.allconf];
    .cq.conf:.cq.allconf[.cq.instance];
    .cq.processConf[.cq.conf];
 };

/ These two will be overridden in the specific q script for each instance
/-------------------------------------------------------------------------
.cq.instance:`;

.cq.processConf:{[c]
  };
/-------------------------------------------------------------------------

.cq.initLogging:{[conf]
    .cq.logDir:".";
    .cq.logPrefix:"";
    .cq.logRollInterval:"24:00:00";
    .cq.logLevel:"INFO,WARN,ERROR,FATAL"; /`INFO`WARN`ERROR`FATAL;
    if [(`$"_cq") in key conf;
        cqConf:conf`$"_cq";
        confKeys:`logdir`logprefix`logrollinterval`loglevel;
        wherePresent:where key[cqConf] in confKeys;
        dkeys:`logDir`logPrefix`logRollInterval`logLevel;
        @[`.cq;dkeys wherePresent;set;cqConf@confKeys wherePresent]
    ];
    .cq.logRollInterval:"N"$ .cq.logRollInterval;
    .cq.logLevel:`$"," vs .cq.logLevel;
    .cq.createNewLogFile[];
    .tm.addTimerRoundRuntime[`.cq.createNewLogFile; enlist `; .cq.logRollInterval];
 };

.cq.logH:0Ni;

.cq.getLogfilePath:{
    .Q.dd[hsym `$.cq.logDir; `$.cq.logPrefix,string[.cq.instance],".log"]
 };
.cq.createNewLogFile:{
    .cq.logFilePath:.cq.getLogfilePath[];
    if [0<count key .cq.logFilePath; .cq.moveLogFile[]];
    .cq.logH:@[hopen;.cq.logFilePath;{[e] '"Error opening log file - ",string[.cq.logFilePath]," - ",e}];
    .log4q.a[.cq.logH; .cq.logLevel];

 };

.cq.moveLogFile:{
    rollLogPath:1_string[.cq.getLogfilePath[]],".",string[.z.d],"_",string[.z.t];
    if [not null .cq.logH;
        @[hclose;.cq.logH;{[e] 0N!"Error closing log file - ",string[.cq.logFilePath]," - ",e}]
    ];
    @[system;"mv ",(1_string[.cq.logFilePath])," ",rollLogPath;{[e] 0N!"Error rolling log file - ",string[.cq.logFilePath]," - ",e}];    
 };





.cq.hconns:([instance:`$()] handle:`int$(); direction:`$(); isconnected:`boolean$(); disconnecttime:`timestamp$(); keepopen:`boolean$(); onopen:());
`.cq.hconns upsert (`;0Ni; `; 0b; 0Np; 0b; ::);
/x - instance name from config
/keepopen - if true, then try reconnecting if the connection is lost
/onopen - alled each time the connection is opened


.cq.hopen:{[ins; keepopen; onopen]    
    th:.cq.hconns[ins];
    if [not null th`handle; :th`handle];
    if [not ins in key .cq.hconns;
        `.cq.hconns upsert (ins;0Ni;`out;0b; 0Np; keepopen;onopen)
    ];
    .cq.dohopen[ins]
    /@[`.cq.dohopen;ins;{}]
 };

.cq.dohopen:{[ins]
    if [not ins in key .cq.hconns; '"hopen - no config for instance ",string[x]];
    th:.cq.hconns[ins];
    cfg:.cq.allconf[ins];
    if [not all `host`port in key cfg; '"hopen - no config for instance ",string[x]];
    url:hsym `$cfg[`host],":",string[cfg`port];
    h:@[hopen;url;{[url; ins; e] '"Error opening connection to [",string[ins],"] = [",string[url],"] - ",e}[url;ins]];
    INFO "Connected to [",string[ins],"]@[",string[url],"]";
    h@(`.cq.registerHandle;.cq.instance);
    update handle:h, isconnected:1b, disconnecttime:0Np from `.cq.hconns where instance=ins;
    if [not null th`onopen; .[th`onopen;(ins;h);{[ins;e] ERROR "Error calling onopen for instance ",string[ins]," - ",e}[ins]]];
    h
 };

.cq.hclose:{[ins]
    if [not ins in key .cq.hconns; '"hopen - no config for instance ",string[x]];
    th:.cq.hconns[ins];
    h:th`handle;
    delete from `.cq.hconns where instance=ins;
    if [not null th`handle; @[hclose; h; {[ins;h;e] ERROR "Error closing connection to [",string[ins],"], handle [",string[h],"- ",e}[ins;h]]];
 };

.cq.h:{[ins]
    if [not ins in key .cq.hconns; '"hopen - no config for instance ",string[x]];
    .cq.hconns[ins]`handle
 };

.cq.registerHandle:{[ins]
    `.cq.hconns upsert (ins;.z.w;`in;1b;0Np;0b;0b);
 };

.cq.attemptReconnect:{
    toReconnect:exec instance from `.cq.hconns where isconnected=0b, keepopen=1b, direction=`out;
    {@[.cq.dohopen; x; {[ins;e] ERROR "Error connecting to ",string[ins]," - ",e}[x]]} each toReconnect;
 };

.tm.addTimer[`.cq.attemptReconnect; enlist `; 2000];

.cq.pc:{[h] };

.z.pc:{[h]    
    update handle:0Ni, isconnected:0b, disconnecttime:.z.p from `.cq.hconns where handle=h;
    /delete from `.cq.hconns where handle=h;
    .cq.pc[h];
 };



