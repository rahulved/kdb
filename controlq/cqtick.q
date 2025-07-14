/ Add batching
system "e 1";
system "c 500 500";

.u.tplogDir:"./tplogs";
.u.tplogPrefix:"tplog_";
.u.tplogRollInterval:`timespan$12:00:00;
.u.batchSize:1;
.u.maxBatchTime:`timespan$0;
.u.schemafilePath:"schema.q";

.u.getNextRollTime:{
    .z.p+.u.tplogRollInterval-.z.p mod `long$.u.tplogRollInterval
 };

.u.nextRollTime:.u.getNextRollTime[];
.u.tph:0Ni;
.u.tplastFileOpenTime:0Np;
.u.tplogPath:`;

.u.sendupdNow:{[t;d]    
    d:update time:.z.p from d;
    .u.tph enlist (`upd;t;value flip d);
    broadcastHandles:.u.alltblallsyms,.u.tblallsymsubs[t]; /(exec handle from .u.tblallsymsubs where tbl=t);
    /broadcastHandles:broadcastHandles where broadcastHandles in key[.z.W];
    if [count broadcastHandles; -25!(broadcastHandles; (`upd;t;d))];
    
    {[t; d; hs] neg[hs[0]] (`upd; t; select from d where sym in hs[1])}[t;d] each .u.tblsymsubs[t]; /0!select sym from .u.tblsymsubs where (tbl=t) or tbl=`; 

 };

.u.sendupdBatch:{[t;d]
    t insert d;
    if [count[value t]>.u.batchSize;
        .u.sendupdNow[t;value t];
        t set 0#value t
    ];
 };

.u.sendupd:.u.sendupdNow;


.cq.processConf:{[conf]
    if [not `tpconfig in key conf; 
        WARN "No tpconfig found in config.json. Using default values";
        :()
    ];
    INFO "Processing tpconfig";
    tpconf:conf`tpconfig;
    if [`schemafile in key tpconf; .u.schemafilePath:tpconf`schemafile];
    if [`tplogdir in key tpconf; .u.tplogDir:tpconf`tplogdir];
    if [`tplogprefix in key tpconf; .u.tplogPrefix:tpconf`tplogprefix];
    if [`tplogrollinterval in key tpconf; .u.tplogRollInterval:"N"$tpconf`tplogrollinterval];
    if [`batchsize in key tpconf; .u.batchSize:`long$tpconf`batchsize];
    if [`maxbatchtime in key tpconf; .u.maxBatchTime:"N"$tpconf`maxbatchtime];

    .u.nextRollTime:.u.getNextRollTime[];
    INFO "Starting tick instance ",string[.cq.instance];
    INFO "TP log dir: ",.u.tplogDir;
    INFO "TP log prefix: ",.u.tplogPrefix;
    INFO "TP log roll interval: ",string[.u.tplogRollInterval];
    INFO "Loading schema file: ",.u.schemafilePath;
    INFO "Batch size: ",string[.u.batchSize];
    INFO "Max batch time: ",string[.u.maxBatchTime];
    INFO "Loading schema file: ",.u.schemafilePath;

    system "l ",.u.schemafilePath;

    if [(.u.batchSize>0) and (.u.maxBatchTime>0);
        .u.sendupd:.u.sendupdBatch;
        .tm.addTimer[`.u.flushBatch;enlist `; .u.maxBatchTime]
    ];
 };

system "l cqcommon.q";

/.cq.instance:`tp1;






/.cq.init[];

.u.ticktbls:tables`;
.u.schemadict:.u.ticktbls!{select[0] from x} each .u.ticktbls;
.u.colsdict:cols each .u.schemadict;
.u.alltblallsyms:();
.u.tblallsymsubs:()!();
.u.tblsymsubs:()!();
.u.timerIntervalMs:2000;

.u.subs:([] handle:`int$(); tbl:`$(); sym:`$());

.u.refreshHandleTables:{
    .u.alltblallsyms: exec handle from .u.subs where null tbl, null sym;
    /make dictionaries below general so that we don't get a ONh handle for tables that are not subbed
    .u.tblallsymsubs: (enlist[`.u.subs]!enlist[()]),(exec handle by tbl from .u.subs where not null tbl, null sym);
    .u.tblsymsubs: (enlist[`.u.subs]!enlist[()]),(exec {flip (key[x];value[x])} sym@group handle by tbl from .u.subs where not null sym);
 };

/@[system;"mkdir -p ",.u.tplogDir;{[e] 0N!"err"; '"Error creating tplogDir: [",.u.tplogDir,"] - ",e}];




.u.createTpLogFile:{   
   .u.tplogPath: .Q.dd[`$":",.u.tplogDir;`$.u.tplogPrefix,"_",string[.cq.instance],"_",(string[.z.d] except/ ".:"),(string[.z.t] except/ ".:"),".log"];   
   .[.u.tplogPath;();:;()];
   .u.tph:hopen .u.tplogPath;   
   INFO "TP log file: ",string[.u.tplogPath],"\n";
 };


.u.checkTpLogfile:{
    if [not count key .u.tplogPath; 
        WARN "TP log file not found at [",string[.u.tplogPath],"]. Creating new one. Some writes may have been lost";
        .u.tph:0Ni
    ];
    if [null[.u.tph] or .z.p>.u.nextRollTime;
        if [.u.tph>0; @[hclose;.u.tph;{0N!x}]];
        .u.createTpLogFile[];
        .u.tplastFileOpenTime:.z.p;
        .u.nextRollTime:.u.getNextRollTime[];
        ];

 };


.u.sub:{[t;s]
  if [not[null t] and not t in .u.ticktbls; '"table na ",string[t]];
  if [0<count select i from .u.subs where handle=.z.w, tbl=t, sym~\:s; :()];
  / Either the subscriber is subscribing again for all syms or for a specific sym. Specific sym will override the all syms subscription
  delete from `.u.subs where handle=.z.w, tbl=t, null sym;
  `.u.subs insert flip cols[.u.subs]!(.z.w; t; (),s);
  .u.subs:distinct .u.subs;
  .u.refreshHandleTables[];
  $[null t; flip (key[.u.schemadict];value[.u.schemadict]); flip (enlist[t];enlist .u.schemadict@t)]  
 };


.u.flushBatch:{
    tbls:.u.ticktbls where 0<count each value each .u.ticktbls;
    .[.u.sendupdNow;;{[e] ERROR "Error sending update ",e}] each flip (tbls;value each tbls);
    .[set] each flip (tbls;0#/: value each tbls);
 };

.u.updtbl:{[t;d]
    if [not t in .u.ticktbls; '"table na ",string[t]];
    /d:update time:.z.p from d;    
    d:.u.colsdict[t]#d;    
    .u.sendupd[t;d];
 };

.u.updlst:{[t;d]
    if [not t in .u.ticktbls; '"table na [",string[t],"]"];
    if [12h<>type first d; d:(enlist count[first d]#.z.p),d];
    d:count[.u.colsdict[t]]#d; / any extra columns are truncated    
    d:flip .u.colsdict[t]!d;
    /d:update time:.z.p from d;
    .u.sendupd[t;d];
 };

.u.upd:{[t; d] 
    $[0h=type d; .u.updlst[t;d]; .u.updtbl[t;d]];
 };

.cq.pc:{[h] 
    delete from `.u.subs where handle=h;
    .u.refreshHandleTables[]
 };

.z.exit:{
    if [.u.tph;  @[hclose;.u.tph;{0N!x}]];
    / flush all pending broadcasts
    if [@[count;.u.alltblallsyms;{0b}]; @[-25!;(.u.alltblallsyms; ::);{0N!x}]];
 };

if [not .cq.istesting; @[.u.checkTpLogfile;`;{'"Error checking tplog file: ",x}]];
/system "t ",string[.u.timerIntervalMs];
/.z.ts:{
/    @[.u.checkTpLogfile;`;{'"Error checking tplog file: ",x}];
/ };




.u.backlog:([handle:`int$()] time:(); bytes:());

.u.checkBacklog:{
    newBacklog:{([handle:key x]; time2:count[value x]#enlist .z.p; bytes2:enlist each value x)} sum each .z.W;
    keeplast:{(0|(count each x)-10)_'x};
    .u.backlog:1!select handle, time:keeplast (time,'time2), bytes:keeplast (bytes,'bytes2) from (.u.backlog,'newBacklog) where handle in exec handle from .u.subs;
    /TBC - Actual monitoring - also check ss -m to check tcp buffer
    /ss -pim -t state established dst :5010
 };

.tm.addTimerRoundRuntime[`.u.checkTpLogfile;enlist `; `timespan$00:00:02];
.tm.addTimer[`.u.checkBacklog;enlist `; `timespan$00:00:05];



