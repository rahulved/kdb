
/hdb writedown process

.cq.processConf:{[conf]
  if [not `hdbwriteconfig in key conf; '"No hdbwriteconfig found for instance [",string[.cq.instance],"]"];
  conf:conf`hdbwriteconfig;
  reqConf:`hdbdir`hdbtplogdir`completedtplogdir`schemafile;
  if [not all reqConf in key conf; '"Invalid hdbwriteconfig for instance [",string[.cq.instance],"] missing [",.Q.s1[reqConf except key conf],"]"];
  .hw.schemafile:conf`schemafile;
  .hw.hdbdir:hsym `$conf`hdbdir;    /the hdb directory to write to
  .hw.hdbtplogdir:hsym `$conf`hdbtplogdir; /the logs for the hdb writedown
  .hw.completedtplogdir:.Q.dd[hsym `$conf`completedtplogdir; `];
  .hw.tblsymfile:$[`tblsymfile in key conf; `$conf`tblsymfile; (`$())!`$()];
 };

system "l cqcommon.q";

upd:insert;

.hw.processTpLogFiles:{
    files:key .hw.hdbtplogdir;
    file:files where files like "*.log";
    tplogfiles:.Q.dd[.hw.hdbtplogdir;] each files;
    .hw.processTpLogFile each tplogfiles;
 };

.hw.moveTpLogFileToCompleted:{[f]
    fromfile:1_string f;
    tofile:1_string .hw.completedtplogdir;
    @[system;"mv ",fromfile," ",tofile;{[f;t;e] ERROR "Error moving ",string[f]," to ",string[t]," - ",e}[fromfile;tofile]];
 };

.hw.processTpLogFile:{[f]
    INFO "Processing [",string[f],"]";
    nblocks:-11!(-2;f);
    if [nblocks=0; 
        ERROR "Error processing [",string[f],"] - 0 blocks to read";
        .hw.moveTpLogFileToCompleted[f];
        :()
    ];
    system "l ",.hw.schemafile;  /clear out all the tables
    INFO "Reading ",string[nblocks]," blocks from [",string[f],"]";
    @[-11!;(nblocks;f);{[f;e] '"Error processing [",string[f],"] - ",e}[f]]; 

    / move all the tables to the hwd namespace  
    /.hwd.a:`;   /just initialise a random value
    tblnames:tables[];
    {[t] .hw.writeTable[t;value t]; t set ()} each tblnames;

    .hw.writeTable each tblnames;
    .hw.moveTpLogFileToCompleted[f];
 };

.hw.writeTable:{[t;d]
    INFO "Processing table [",string[t],"]";
    /if [not t in key[.hwd]; '"Table [",string[t],"] not found in schema file [",string[.hw.schemafile],"]"];    
    /t:update `s#time, `g#sym from `time xasc value t;   /first sort by time because we want individual date chunks to be written to the hdb
    dates:exec distinct `date$time from d;
    .hw.writeTableForDate[t;d] each dates;
 };

.hw.filterForTypeIntegrity:{[tbl;dt;tbldata]
    / Remove any rows that have multiple types in them, keep the rest, record errors
    goodrows:({distinct (x where x in y),(y where y in x)}/) value where each tp='first each idesc each (count each) each group each tp:(type each) each flip[tbldata];
    ret:tbl@goodrows;
    d:any each 1_'differ each tp; /(type each) each flip[tbldata];
    if [count where d; 
        badrows:til[count tbl] except goodrows;
        ERROR "Type mismatch in table [",string[tbl],"] for date [",string[dt],"] columns:[",.Q.s1[where d],"], removed [",string[count[badrows]],"] rows:[",.Q.s1[badrows],"]";
    ];
    ret
 };

.hw.writeTableForDate:{[t;d;dt]
    INFO "Writing table [",string[t],"] for date [",string[dt],"]";
    data:select from d where (`date$time)=dt;
    data:.hw.filterForTypeIntegrity[t;dt;data];
    if [0=count data; :()];
    /system "l ",1_string[.hw.hdbdir];   /load the hdb
    
    origdata:();
    tblhdbdir:(.Q.dd/)(.hw.hdbdir;dt;t);
    if [count key tblhdbdir;
        symfilename:$[t in key .hw.tblsymfile; .hw.tblsymfile[t]; `sym];    
        symfilepath:.Q.dd[.hw.hdbdir;symfilename];
        load symfilepath;
        origdata:get tblhdbdir;
        origdata:@[origdata;exec c from meta[origdata] where t in "sS";value];
        data:origdata,(cols[origdata]#data);
    ];
    
    t set `sym`time xasc data;
    $[t in key .hw.tblsymfile; 
        .Q.dpfts[.hw.hdbdir;dt;`sym;t;.hw.tblsymfile[t]];
        .Q.dpft[.hw.hdbdir;dt;`sym;t]
    ];



 };

