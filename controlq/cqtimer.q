.tm.granularityms:1000;

.tm.timers:([] id:`long$();fn:`$(); arglist:(); freq:(); lastrun:`timestamp$(); nextrun:`timestamp$(); roundruntime:`boolean$(); lastrunduration:`timespan$(); lasterror:());

.tm.id:0;

.tm.getNextRunTime:{[freq;roundruntime]    
    .z.p+freq - roundruntime*.z.p mod `long$freq
 };
.tm.addTimer:{[fn;arglist;freq]
    .tm.addTimerHelper[fn;arglist;freq;0b]
 };
.tm.addTimerRoundRuntime:{[fn;arglist;freq]
    .tm.addTimerHelper[fn;arglist;freq;1b]
 };
 
.tm.addTimerHelper:{[fn;arglist;freq; roundruntime]
    .tm.id+:1;
    freq:`timespan$freq;
    `.tm.timers upsert (.tm.id;fn;(),arglist;freq;0Np;.tm.getNextRunTime[freq;roundruntime];roundruntime;0Nn; enlist "");
    .tm.id
 };

.tm.removeTimer:{[rid]
    delete from `.tm.timers where id=rid;
 };

.tm.runTimers:{[]
    toRun:select  from .tm.timers where nextrun<.z.p;
    .tm.runTimer each toRun;
 };

.tm.runTimer:{[tm]    
    update lastrun:.z.p, lasterror:enlist "" from `.tm.timers where id=tm`id;
    st:.z.p;
    @[.[tm`fn;]; tm`arglist; .tm.handleError[tm;]];    
    et:.z.p;
    update nextrun:.tm.getNextRunTime[tm`freq;tm`roundruntime], lastrunduration:et-st from `.tm.timers where id=tm`id;
  };

.tm.handleError:{[tm;err]
    err:"Error running timer ",string[tm[`id]]," ",string[tm[`fn]],": ",err;
    ERROR err;
    update lasterror:enlist err from `.tm.timers where id=tm`id;
 };

.z.ts:{
    .tm.runTimers[];
  };

system "t ",string[.tm.granularityms];

