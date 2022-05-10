<h1>Capture transfer events in Apecoin to kdb using kafka</h1>

This code can be used to capture events from any ethereum contract into kdb. I've used Apecoin transfer events as an example.
<p>
Apecoin is a token on the ethereum blockchain. Tokens exist as smart contracts on the blockchain and have callable functions. Typically when the transfer function is called to send tokens from one address to another, a Transfer event is emmitted. 
</p>
<p>
More on apecoin here - https://apecoin.com/
The contract can be viewed here -
https://etherscan.io/address/0x4d224452801aced8b2f0aebe155379bb5d594381
</p>
<p>
This code subscribes to these events from the contract via a nodejs client which then publishes the event to kafka. A kdb process subscribes to kafka and stores the events as a table. The set up is probably the most complicated part of this - the code is simple since its just a proof of concept.
</p>
<p>
The end result looks like this, showing the timestamp in kdb, timestamp from the node.js subscriber, sending address, receiving address, value in Wei (ether*10^18), actual coin value (value/10^18)
<br/>
<img src="./transfer_table.png"/>
</p>
<p>
Setup - Go through the instructions here but I've outlined them step by step below -
https://github.com/KxSystems/kafka#building-and-installation
</p>
<h3>1. Setting up Zookeeper and Kafka</h3>

<p>
Download and install zookeeper from here:<br/>
https://zookeeper.apache.org/releases.html
</p>
<p>
Download and install kafka from here:<br/>
https://kafka.apache.org/downloads
</p>
<p>
Run zookeeper and kafka (change directory to wherever the files are unzipped)<br/>

~/apps/zookeeper/latest/bin$<b> ./zkServer.sh start ../../../kafka/latest/config/zookeeper.properties</b><br/>
~/apps/kafka/latest$<b> bin/kafka-server-start.sh config/server.properties</b><br/>
</p>


<h3>2. Libraries</h3>
<h4>librdkafka</h4>
<p>
You'll need to build librdkafka from source<br/>
https://github.com/edenhill/librdkafka<br/>

```
git clone https://github.com/edenhill/librdkafka.git
cd librdkafka
make clean  # to make sure nothing left from previous build or if upgrading/rebuilding
# If using OpenSSL, remove --disable-ssl from configure command below
# On macOS with OpenSSL you might need to set `export OPENSSL_ROOT_DIR=/usr/local/Cellar/openssl/1.0.2k` before proceeding


# 32 bit
./configure --prefix=$HOME --disable-sasl --disable-lz4 --disable-ssl --mbits=32
# 64 bits
./configure --prefix=$HOME --disable-sasl --disable-lz4 --disable-ssl --mbits=64

make
make install
```

<br/>
make install will install files in $HOME/lib and $HOME/include<br/>
</p>
<h4>kx's kafka library</h4>
<p>

You'll need to build kx's kfk library<br/>

```
export QHOME=.......
#for now set KAFKA_HOME to $HOME so make can pick up librdkafka from the previous build
export KAFKA_HOME=$HOME
git clone https://github.com/KxSystems/kafka.git
make
make install
```

<br/>
</p>









