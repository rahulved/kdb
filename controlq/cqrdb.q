.r.configName:`rdbconfig;
.r.processConf:{[conf]
    .r.dataDuration:@["N"$;conf[`dataduration];{0N!x; '"Error reading dataDuration from config - ",x; 0Nn}];
 };
system "l cqtpsubcommon.q";

/temp for debug below, otherwise upd:insert
upd:{[t;d] t insert d};

.r.clearData:{
    {delete from x where time<=.z.p-.r.dataDuration} each distinct .r.subs`tbl;
 };

 if [.r.dataDuration>0; .tm.addTimer[`.r.clearData;enlist `; `timespan$00:01:00]];









