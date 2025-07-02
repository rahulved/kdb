.cq.processConf:{[conf]
    INFO "Processing configuration for instance ",string[.cq.instance];
    $[`qexec in key conf; 
        [
            /qexec can have environment variables in the form ${VARNAME}, e.g., ${QHOME}/q.sh
            t1:"}" vs/: "${" vs conf`qexec;
            .cq.qexec:raze t1[0],raze each .[1_t1; (til count 1_t1;0); :; getenv[`$first each 1_t1]]

        ];
      `qhome in  key conf;
        .cq.qexec:conf[`qhome],"/q";
       0<count getenv`QHOME;
         .cq.qexec:getenv`QHOME,"/q";
         .cq.qexec:"q"
    ];       

    .cq.cloptions:[`cloptions in key conf; conf`cloptions;""];
 };

system "l cqcommon.q";

/.cq.instance:`$"cqagent";



.cq.qexec:"q";
.cq.cloptions:"";

system "e 1";





.cq.instances:([instance:`$()] handle:`int$(); pid:`int$(); lastheartbeat:`timestamp$(); starttime:`timestamp$(); registertime:`timestamp$(); 
              shutdownreqtime:`timestamp$(); shutdownacktime:`timestamp$(); host:`$(); port:`int$(); islocal:`boolean$(); lagtime:`timespan$());

`.cq.instances upsert flip `instance`starttime!(enlist .cq.instance; enlist .z.p);

.cq.loadInstances:{
  / Load all instances bcause in an emergency might want to start any instance on any host
  `.cq.instances upsert flip enlist[`instance]!enlist key .cq.allconf;
  localhosts:("localhost";"." sv string 256 vs .z.a;string .z.h);  
  localInstances:key[.cq.allconf] where value any each localhosts~\:/:.cq.allconf[;`host];
  update islocal:1b from `.cq.instances where instance in localInstances;  
 };


.cq.resetInstance:{[ins]
  if [not ins in key .cq.instances; '"No such instance in .cq.instances",string[ins]];
  update lastheartbeat:0Np, starttime:0Np, registertime:0Np, pid:0Ni, handle:0Ni, shutdownreqtime:0Np, shutdownacktime:0Np, host:`, port:0Ni, lagtime:0Nn from `.cq.instances where instance=ins
  };

.cq.startInstance:{[ins]
    //TBC - do host check
    if [not ins in key .cq.allconf; '"No config for instance ",string[ins]];
    if [not ins in key .cq.instances; '"No such instance in .cq.instances",string[ins],". Has .cq.loadInstances been called?"];
    conf:.cq.allconf[ins];
    if [not all `host`port`init in key conf; '"No host/port/init in config for instance ",string[ins]];
    insdata:.cq.instances[ins];    
    
    if [not insdata`islocal; '"Not a local instance ",string[ins], ". Should run on ",conf`host];
    if [0<insdata`pid; '"Instance ",string[ins]," already running"];
    .cq.startInstanceUnsafe[ins; 0Ni]; /null port = use default conf port
 };

.cq.pc:{[h]
    update handle:0Ni from `.cq.instances where handle=h;
  };

.cq.shutdownAck:{[ins;ts]
  INFO "Received shutdown ack for instance ",string[ins];
  lag:.z.p-ts;
  update shutdownacktime:.z.p, handle:0Ni, pid:0Ni, lagtime:lag from `.cq.instances where instance=ins;
 };

.cq.sigintInstance:{[ins]
  if [not .cq.instances[ins][`pid]>0; INFO "Instance ",string[ins]," not running to kill"];
  INFO "Interrupting instance [",string[ins], "], pid=[",string[.cq.instances[ins][`pid]],"]";
  @[system; "kill -2 ",string[.cq.instances[ins][`pid]];{ERROR "Error interrupting instance ",string[ins]," - ",x}];
 };

.cq.killInstance:{[ins]
  if [not .cq.instances[ins][`pid]>0; INFO "Instance ",string[ins]," not running to kill"];
  INFO "Killing instance [",string[ins], "], pid=[",string[.cq.instances[ins][`pid]],"]";
  @[system; "kill -9 ",string[.cq.instances[ins][`pid]];{ERROR "Error killing instance ",string[ins]," - ",x}];
 };

.cq.stopInstance:{[ins]
  if [not ins in key .cq.instances; '"No such instance in .cq.instances",string[ins],". Has .cq.loadInstances been called?"];
  if [not .cq.instances[ins][`pid]>0; '"Instance ",string[ins]," not running"];
  if [not .cq.instances[ins][`handle]>0; '"Instance ",string[ins]," not connected"];
  INFO "Shutting down instance ",string[ins];
  h:.cq.instances[ins][`handle];
  update shutdownreqtime:.z.p from `.cq.instances where instance=ins;
  .tm.addTimerOnce[`.cq.killInstance; enlist ins; .z.p+`timespan$00:00:10];
  neg[h] (`.cq.shutdown;`)
 };


.cq.getCmdLine:{[ins; port]   
    if [not ins in key .cq.allconf; '"No config for instance ",string[ins]];
    conf:.cq.allconf[ins];            
    if [null port; port:conf`port];
    /Specify the instance in the cmdline so its easier to search for with a ps
    "nohup ",.cq.qexec," ",conf[`init]," -instance ",string[ins]," -p ",string[port]," -agentport ",string[.cq.myport],$[`cloptions in key conf; " ",conf[`cloptions];""]," > ",.cq.logDir,"/start_",string[ins],".log 2>&1 &"
  };

/ In production sometimes you need to run an instance on a different port in an emergency
.cq.startInstanceUnsafe:{[ins; port]
    /No checks here - if you want safety call .cq.startProc
    cmdline:.cq.getCmdLine[ins; port];    
    INFO "Starting instance [",string[ins],"] on port [",string[port],"] with command line [",cmdline,"]";
    system cmdline;
    update starttime:.z.p from `.cq.instances where instance=ins;
 };

.cq.agentregister:{[ins;pd;hst;prt;ts]
  lag:.z.p-ts;
  if [not ins in key .cq.instances; ERROR "No such instance to register in .cq.instances: [",string[ins],"]"; :()];
  update pid:pd, host:hst, port:prt, handle:.z.w, registertime:.z.p, lagtime:lag from `.cq.instances where instance=ins;
 };

.cq.agentheartbeat:{[ins;ts;pd]
  lag:.z.p-ts;
  update lastheartbeat:.z.p, handle:.z.w, pid:pd, lagtime:lag from `.cq.instances where instance=ins;
  };


.cq.init[];
INFO "Loading instances";
.cq.loadInstances[];
