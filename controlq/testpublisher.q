system "l cqcommon.q";

.cq.instance:`fh1;
.cq.processConf:{[conf]
 };
.cq.init[];

pubintervalms:1000;

roundprice:{%[floor 0.00005+10000*x;10000]};
roundqty:{100+100*div[x;100]};

getQuotes:{[n]
    s:`a`b`c;
    p:s!100.0 200.0 300.0;
    c:s!0.02 0.04 0.05;
    syms:n?s;
    times:asc .z.p-n?`timespan$pubintervalms*1e6;
    g:group[syms];
    tg:([] sym:key g; pos:value g);
    tg:update num:count each pos from tg;    
    tg:update px:p[sym]+sums each (num?\:-1 1)*num?'c[sym] from tg;    
    mids:raze[tg`px]@iasc raze[tg`pos];   
    spreads:n?0.0001;
    bids:roundprice mids*(1-spreads); /%[floor 0.00005+10000*mids*(1-spreads);10000];
    asks:roundprice mids*(1+spreads);    
    bidvols:100*1+n?50j;
    askvols:100*1+n?50j;
    quotes:([] time:.z.p; sym:`g#syms; qtime:`s#times;  bid:bids; ask:asks; bidsize:bidvols; asksize:askvols);
    quotes:update bids:roundprice bid+'1-(0,'sums each (floor 1+count[i]?6)?'c[sym]), asks:roundprice ask+'1+(0,'sums each (floor 1+count[i]?6)?'c[sym]) from quotes;
    /quotes:update bidsizes:(bidsize,'100+100*div[(-1+count each bids)?'5000 ;100]), 
    /       asksizes:(asksize,'100+100*div[(-1+count each asks)?'5000 ;100]) from quotes;
    quotes:update bidsizes:(bidsize,'100*1+(-1+count each bids)?'50j), 
                  asksizes:(asksize,'100*1+(-1+count each asks)?'50j) from quotes;

    quotes
 };

getTrades:{[n;quotes]
    s:`a`b`c;
    syms:n?s;
    sides:n?`b`s;
    times:asc .z.p-n?`timespan$pubintervalms*1e6;
    trades:([] sym:`g#syms; ttime:`s#times; side:sides);
    trades:aj[`sym`time; update time:ttime from trades; update time:qtime from quotes];
    trades:update maxtradesize:sum each ?[side=`b; asksizes; bidsizes] from trades;
    trades:update qty:roundqty (n?.9)*maxtradesize from trades;
    trades:update px:roundprice (deltas each qty&'sums each ?[side=`b;asksizes;bidsizes]) wavg' ?[side=`b;asks;bids] from trades;
    trades:select time:.z.p, `g#sym, `s#ttime, side, px, qty from trades;
    trades
 };


dopub:{
    h:.cq.h[`tp1];
    if [null h; :()];
    
    /if [null .p.tph; :()];
    nq:first 1+1?200;
    nt:first 1+1?50;
    quotes:getQuotes nq;
    neg[h] (`.u.upd;`quote;value flip quotes);
    neg[h] (`.u.upd;`trade;value flip getTrades[nt;quotes]);
 };





.cq.hopen[`tp1;1b;`];

\
/.p.tploc:`:localhost:5010;
openTpConn:{
    .cq.hopen[`tp1;1b;`];
    /.p.tph:@[hopen;.p.tploc;{0Nh}];    
 };

/system "t 2000";
/.z.ts:{
/    if [null .p.tph; openTpConn[]];
/ };

/.z.pc:{[h]
/    if [h=.p.tph; .p.tph:0Nh];
/ };
openTpConn[];

.tm.addTimer[`.p.dopub;enlist `; `timespan$pubintervalms];
/system "t ",string[pubintervalms];
/.z.ts:{dopub[]};

.cq.init[];