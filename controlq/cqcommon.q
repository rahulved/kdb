system "l log4q.q";

.log4q.fm:"%p %c\t%f:%m\r\n";

system "l cqtimer.q";

.cq.myport:system "p";
/ Instance name and agent port are command line options
/-------------------------------------------------------------------------
.cq.clopts:.Q.opt .z.x;
if [not `instance in key .cq.clopts; '"Instance not specified in command line (-instance <instance name>)"];
.cq.instance:first `$.cq.clopts`instance;
if [not `agentport in key .cq.clopts; '"Agent port not specified in command line (-agentport <port>)"];
.cq.agentport:first "I"$.cq.clopts`agentport;


.cq.init:{  
    INFO ".cq.init called";  
    configPath:"cqconfig.json";
    args:.Q.opt .z.x;
    if [`configpath in key args; if [0<count args`configpath; configPath:args`configpath]];
    .cq.allconf:@[read0;hsym `$configPath;{'"Unable to find ",configPath," - ",x}];
    .cq.allconf:@[.j.k; raze .cq.allconf;{'"Unable to parse ",configPath," - ",x}];
    .cq.allconf[;`port]:`int$.cq.allconf[;`port];

    /Agent host and port
    .cq.allconf[`cqagent;`host]:":";
    .cq.allconf[`cqagent;`port]:.cq.agentport;

    .cq.initLogging[.cq.allconf];
    .cq.conf:.cq.allconf[.cq.instance];
    .cq.processConf[.cq.conf];
    .cq.hopen[`cqagent;1b;.cq.instanceregister]
 };



.cq.initLogging:{[conf]
    .cq.logDir:".";
    .cq.logPrefix:"";
    .cq.logRollInterval:"24:00:00";
    .cq.logLevel:"INFO,WARN,ERROR,FATAL"; /`INFO`WARN`ERROR`FATAL;
    if [`cqagent in key conf;
        cqConf:conf`cqagent;
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
    if [ins=`cqagent; '".cq.hclose - cannot close cqagent connection. Close handle,",string[th`handle]," directly instead if required"];
    delete from `.cq.hconns where instance=ins;
    if [h>0; @[hclose; h; {[ins;h;e] ERROR "Error closing connection to [",string[ins],"], handle [",string[h],"- ",e}[ins;h]]];
    INFO "Disconnected from [",string[ins],"]";
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
.cq.agenth:0Ni;
.z.pc:{[h]    
    update handle:0Ni, isconnected:0b, disconnecttime:.z.p from `.cq.hconns where handle=h;
    if [h=.cq.agenth; .cq.agenth:0Ni];

    /delete from `.cq.hconns where handle=h;
    .cq.pc[h];
 };



.cq.instanceregister:{[ins;h]
    INFO "Sending instance register to agent on handle ", string[h];
    .cq.agenth:h;
    neg[h] (`.cq.agentregister;.cq.instance;.z.i;.z.h;system "p"; .z.p);
    .tm.addTimer[`.cq.instanceheartbeat; enlist `; `timespan$00:00:05];
  };

.cq.instanceheartbeat:{
    if [not null .cq.agenth; neg[.cq.agenth] (`.cq.agentheartbeat;.cq.instance;.z.p)];
 };


.cq.shutdown:{
    INFO "Shutting down instance ",string[.cq.instance];    
    h:.cq.agenth^.z.w;
    INFO "Sending shutdown ack on handle ", string[h];
    if [not null h; h (`.cq.shutdownAck;.cq.instance;.z.p)];
    INFO "Closing all connections";    
    {@[hclose;x;{[x;e] ERROR "Error closing connection to [",string[x],"] - ",e}[x]]} each exec distinct handle from .cq.hconns where handle>0;        
    /.cq.hclose each key .cq.hconns;
    INFO "Exiting...";
    /.tm.addTimer[`exit;enlist 0;.z.p+00:00:01];
    exit[0];
 };

if [.cq.instance<>`cqagent;
    INFO "Calling .cq.init for instance ",string[.cq.instance];
    .cq.init[]
 ];

.z.exit:{
    INFO "Received exit signal";
 };