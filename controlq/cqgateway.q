.cq.processConf:{[c]
    if [not `gwconfig in key c; '"No gwconfig found for instance [",string[.cq.instance],"]"];
    conf:c`gwconfig;
    if [not `instancegroups in key conf; '"No instancegroups found in gwconfig for [",string[.cq.instance],"]"]; 
    .gw.instanceGroups:`$conf`instancegroups;
 };

system "l cqcommon.q";

.gw.queryId:0;
.gw.config:ungroup {([] grp:key x; instance:(),value x; handle:0Ni)} .gw.instanceGroups;
.gw.queries:([] queryid:`long$(); grps:(); query:(); reduce:(); receivedtime:`timestamp$(); callerhandle:`int$(); remgrps:());
.gw.sentQueries:([] grp:`$(); instance:`$(); handle:`int$(); senttime:`timestamp$(); queryid:`long$());
.gw.queryResponses:([] queryid:`long$(); grp:`$(); response:());

.cq.pc:{[h]
    update handle:0Ni from `.gw.config where handle=h;

    / If its a user thats gone, then remove all the queries that the user has sent
    queryIds:exec queryid from .gw.queries where callerhandle=h;
    delete from `.gw.sentQueries where queryid in queryIds;
    delete from `.gw.queryResponses where queryid in queryIds;
    delete from `.gw.queries where callerhandle=h;
 };

.gw.onConnect:{[ins;h]
    update handle:h from `.gw.config where instance=ins;
 };

.gw.init:{
    .cq.asynchopen[;1b;`.gw.onConnect] each distinct raze value .gw.instanceGroups;    
 };

.gw.querySimple:{[grp;query]
    .gw.query[enlist grp;query;`];
 };
.gw.query:{[grps;query;reduce]
     if [not all ((),grps) in key .gw.instanceGroups; '"Invalid group(s) in query - ",(.Q.s1 grps except key .gw.instanceGroups)];
     grps:distinct (),grps;
     .gw.queryId+:1;
    `.gw.queries upsert (.gw.queryId;grps;query;reduce;.z.p;.z.w;grps);
    -30!(::);
    .gw.processQueries[];
 };

.gw.processQueries:{    
    /unprocessedQueries:update remainingGroups:grps@'where each not grps in' sentgrps from (.gw.queries lj select sentgrps:grp by queryid from .gw.sentQueries);
    /unprocessedQueries:select from unprocessedQueries where 0<count each remainingGroups;
    .gw.processQuery each select from .gw.queries where 0<count each remgrps;
  };


.gw.processResponse:{[qid;g;res]
  INFO "Received response for query ",string[qid]," for group ",string[g];
  delete from `.gw.sentQueries where queryid=qid, grp=g;    //first free up the handle so other queries can be sent
  q:select from .gw.queries where queryid=qid;
  if [not count q; :()]; / client's gone away
  q:first q;
  if [first res; /if there's an error, then return the error to the client
    delete from `.gw.queries where queryid=qid;
    delete from `.gw.queryResponses where queryid=qid;
    -30!(q[`callerhandle],res);
    :()
  ];
 
  if [1=count q`grps; (-30!(q[`callerhandle],res)); :()]; /if there was only one group then we're done

  `.gw.queryResponses upsert (qid;g;1_res); / remove the first element which should be true since there was no error.
  if [count[exec distinct grp from .gw.queryResponses where queryid=qid]=count[q`grps];
    res:select response from .gw.queryResponses where queryid=qid;
    if [not null q`reduce;
        res:@[q`reduce;res;{[h;e] -30!(h;1b;e); `}[q`callerhandle]];
        if [not null res; -30!((q[`callerhandle];1b),res)]
    ]
  ];
 };

.gw.processQueryForGroup:{[q;g]
    availableInstances:select from .gw.config where grp=g, handle>0, not instance in (exec distinct instance from .gw.sentQueries);
    if [not count availableInstances; :()];
    instance:availableInstances[0;`instance];
    handle:availableInstances[0;`handle];
    `.gw.sentQueries upsert (g;instance; handle; .z.p;q`queryid);
    update remgrps:remgrps except\: g from `.gw.queries where queryid=q`queryid;
    neg[handle] ({[qid;grp;query] neg[.z.w] (`.gw.processResponse;qid; grp; @[{(0b; value x)};query;{[e] (1b; e)}])};q`queryid;g;q`query);
    

 };
.gw.processQuery:{[q]
    .gw.processQueryForGroup[q;] each q`remgrps;
 };

.gw.init[];
.tm.addTimer[`.gw.processQueries; enlist `; 1000];