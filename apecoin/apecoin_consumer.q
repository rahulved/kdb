\l kfk.q
client:.kfk.Consumer[`metadata.broker.list`group.id!`localhost:9092`0];
data:();
transfer:([] kdbTime:`timestamp$(); nodeTime:`timestamp$(); sender:(); receiver:(); val:(); coins:`float$());
errorRows:();
unixStart:`long$1970.01.01D00:00;

unixToTimestamp:{[strMs]
    `timestamp$unixStart+("J"$strMs)*1000000
    };

weiToEther:{[strWei]
    "F"$(-18_strWei),".",(count[strWei]-18)_strWei
    };

    
consumeTransfer:{[msg]
    d:"c"$msg[`data];
    v:":" vs d;
    r:(.z.p; unixToTimestamp v[0]),1_v,enlist weiToEther v[3];
    `transfer insert r;
    };
    
.kfk.consumecb:{[msg] 
    @[consumeTransfer;msg;{[e] show e,":",.Q.s[msg]; errorRows,::enlist msg}];
    };
    
.kfk.Sub[client;`transfer;enlist .kfk.PARTITION_UA]

