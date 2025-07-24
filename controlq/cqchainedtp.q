.r.configName:`ctpconfig;
.r.processConf:{[conf]
 };

system "l cqtpsubcommon.q";

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

upd:{[t;d]    
    broadcastHandles:.u.alltblallsyms,.u.tblallsymsubs[t]; /(exec handle from .u.tblallsymsubs where tbl=t);
    /broadcastHandles:broadcastHandles where broadcastHandles in key[.z.W];
    if [count broadcastHandles; -25!(broadcastHandles; (`upd;t;d))];
    
    {[t; d; hs] neg[hs[0]] (`upd; t; select from d where sym in hs[1])}[t;d] each .u.tblsymsubs[t]; /0!select sym from .u.tblsymsubs where (tbl=t) or tbl=`; 

 };
