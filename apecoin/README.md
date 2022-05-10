<h1>Capture transfer events in Apecoin to kdb using kafka</h1>

This code can be used to capture events from any ethereum contract into kdb. I've used Apecoin transfer events as an example.
<p>
Apecoin is a token on the ethereum blockchain. Tokens exist as smart contracts on the blockchain and have callable functions. Typically when the transfer function is called to send tokens fromone address to another, a Transfer event is emmitted. 
</p>
<p>
More on apecoin here - https://apecoin.com/
</p>
<p>
This code subscribes to these events from the contract via a nodejs client which then publishes the event to kafka. A kdb process subscribes to kafka and stores the events as a table. The set up is probably the most complicated part of this - the code is simple.
</p>

