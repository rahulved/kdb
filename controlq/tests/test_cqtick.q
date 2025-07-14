.cq.unittest:1b;
tbl1:([] sym:`$(); time:`timestamp$(); price:`float$(); size:`long$());
tbl2:([] sym:`$(); time:`timestamp$(); dt:`date$(); num:`long$());

system "l cqtick.q";

/ no timers will be run
.z.ts:{};

.t.testsub1:{
    .u.sub[`tbl1;`];
    c:count select from .u.subs where tbl=`tbl1, sym=`;
    delete from `.u.subs where tbl=`tbl1, sym=`;
    c=1
 };

