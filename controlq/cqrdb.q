.cq.processConf:{[c]
    conf:c`rdbconfig;
    if [0=count conf; '"No rdbconfig found for instance [",.cq.instance,"]"];
    subs:update `$tp, `int$priority, `$tbls, `$syms from conf[`subs];
    .r.subs:distinct select tp, grp, priority, tbl:tbls, sym:syms from subs; /(count each tbls)#'enlist each syms from subs;
    .r.subs:distinct flip `tp`grp`priority`tbl`sym!flip raze (flip value exec tp, grp, priority from .r.subs),/:'(.r.subs[`tbl] cross' .r.subs[`sym]);
    .r.subs:update handle:0Ni from `grp`priority`tbl xasc 0!select sym by tp, grp, priority, tbl from .r.subs;
    tps:exec distinct tp from .r.subs;
    .r.tpConns:select tp:tps, `$host, `int$port, handle:0Ni, failTime:0Np from .cq.allconf[tps];
    badConns:select from .r.tpConns where null[host] or null[port];
    if [0<count badConns; '"Bad connections found in config - ",(.Q.s1 badConns`tp)];
    .r.dataDuration:@["N"$;conf[`dataduration];{0N!x; '"Error reading dataDuration from config - ",x}];
  };

system "l cqcommon.q";

/ Temporary instead of upd:insert to be able to debug
upd:{[t;d] t insert d};

.cq.instance:`rdb1;




.r.failures:([] grp:`int$(); startTime:`datetime$(); endTime:`datetime$());

.r.openTpConns:{    
    subs:select from .r.subs where (all;null handle) fby grp;
    subs:subs lj `tp xkey select tp, handle, failTime from .r.tpConns;
    subs:update calcPriority:priority+0j^`long$failTime from subs;
    subs:select from subs where calcPriority=(min;calcPriority) fby grp;
    /if there are some handles already here then sub them
   .r.openAndSub[subs;] each exec distinct tp from subs;

 };

.r.openAndSub:{[subs;tpn]
    h:.r.getTpConn[tpn];
    if [not null h; .r.doSubs[select from subs where tp=tpn; h]];
 };

.r.doSubs:{[subs;h]    
    if [not count subs; :()];
    ret:(,/) h@/:`.u.sub,/:flip value exec tbl,sym from subs;    
    if [count ret;        
        ret:ret where not (first each ret) in tables`;
        show ret;
        if [count ret; flip[ret][0] set' flip[ret][1]]
    ];
    .r.subs:.r.subs lj `tp`grp`priority`tbl xkey update handle:h from select tp, grp, priority, tbl from subs;
 };

.r.getTpConn:{[tpn]
    tp:first select from .r.tpConns where tp=tpn;    
    $[not null tp`handle; 
        tp`handle;
        [
            / Don't use the built in reconnect functionality of .cq.hopen here because we only want to connect to one tp at a time from each failure set
            h:.[.cq.hopen;(tpn;0b;`); {[tpn; e] ERROR "Error connecting to ",string[tpn]," - ",e; 0Nh}[tpn]];
            /h: .Q.trp[.cq.hopen; tpn; {[tpn; e;b] ERROR "Error connecting to ",string[tpn]," - ",e,"\n"; 0Nh}[tpn]];
            $[null h; 
                update handle:0Ni, failTime:.z.p from `.r.tpConns where tp=tpn; 
                update handle:h, failTime:0Np from `.r.tpConns where tp=tpn
            ];
            h
        ]
    ]   
 };



.tm.addTimer[`.r.openTpConns;enlist `; `timespan$00:00:02];

.cq.pc:{[h]
    update handle:0Ni, failTime:.z.p from `.r.tpConns where handle=h;
    update handle:0Ni from `.r.subs where handle=h;
 };



/.cq.init[];

.r.openTpConns[];









