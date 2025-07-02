# Projects:

## 1. Control-q
An improved tickerplant and process control framework that includes:
1) cqagent.q - an agent to start and stop configured processes, 
1) cqtick.q - replacement for tick.q that uses timestamps (date and time), automatically rolling tp log files, updates as tables or lists, async broadcast, auto-cutoff of slow consumers
2) cqrdb.q - rdb that does priority based failover between tickerplants.
3) cqtimer.q - a timer library

## 2. Gateway

A snc to async gateway to round robin queries and/or run map-reduce type queries across multiple instances, e.g., of hdb's or rdb's.

## 3. Apecoin
A reader that captures events from the ethereum blockchain - in this case those related to apecoin.
