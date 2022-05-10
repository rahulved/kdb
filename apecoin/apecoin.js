const Web3=require('web3');
var net = require('net');
const Kafka = require('node-rdkafka');
//const { configFromPath } = require('./util');

//Create an infura node here - https://infura.io/ (sign in-> Create New Project) and then uncomment the http web3Provider  below
var infuraUrl='https://mainnet.infura.io/v3/<myInfuraNode>';
//var web3Provider=new Web3.providers.HttpProvider(infuraUrl);

// Next two lines are for a local geth node
// If using an infura node, comment out the next two lines
var localIpc='/home/rahul/dev/ethereum/mainnet/geth.ipc';
var web3Provider=new Web3.providers.IpcProvider(localIpc, net);
const web3=new Web3(web3Provider);

var abi='[{"inputs":[{"internalType":"string","name":"name","type":"string"},{"internalType":"string","name":"symbol","type":"string"},{"internalType":"uint256","name":"totalSupply_","type":"uint256"}],"stateMutability":"nonpayable","type":"constructor"},{"anonymous":false,"inputs":[{"indexed":true,"internalType":"address","name":"owner","type":"address"},{"indexed":true,"internalType":"address","name":"spender","type":"address"},{"indexed":false,"internalType":"uint256","name":"value","type":"uint256"}],"name":"Approval","type":"event"},{"anonymous":false,"inputs":[{"indexed":true,"internalType":"address","name":"from","type":"address"},{"indexed":true,"internalType":"address","name":"to","type":"address"},{"indexed":false,"internalType":"uint256","name":"value","type":"uint256"}],"name":"Transfer","type":"event"},{"inputs":[{"internalType":"address","name":"owner","type":"address"},{"internalType":"address","name":"spender","type":"address"}],"name":"allowance","outputs":[{"internalType":"uint256","name":"","type":"uint256"}],"stateMutability":"view","type":"function"},{"inputs":[{"internalType":"address","name":"spender","type":"address"},{"internalType":"uint256","name":"amount","type":"uint256"}],"name":"approve","outputs":[{"internalType":"bool","name":"","type":"bool"}],"stateMutability":"nonpayable","type":"function"},{"inputs":[{"internalType":"address","name":"account","type":"address"}],"name":"balanceOf","outputs":[{"internalType":"uint256","name":"","type":"uint256"}],"stateMutability":"view","type":"function"},{"inputs":[],"name":"decimals","outputs":[{"internalType":"uint8","name":"","type":"uint8"}],"stateMutability":"view","type":"function"},{"inputs":[{"internalType":"address","name":"spender","type":"address"},{"internalType":"uint256","name":"subtractedValue","type":"uint256"}],"name":"decreaseAllowance","outputs":[{"internalType":"bool","name":"","type":"bool"}],"stateMutability":"nonpayable","type":"function"},{"inputs":[{"internalType":"address","name":"spender","type":"address"},{"internalType":"uint256","name":"addedValue","type":"uint256"}],"name":"increaseAllowance","outputs":[{"internalType":"bool","name":"","type":"bool"}],"stateMutability":"nonpayable","type":"function"},{"inputs":[],"name":"name","outputs":[{"internalType":"string","name":"","type":"string"}],"stateMutability":"view","type":"function"},{"inputs":[],"name":"symbol","outputs":[{"internalType":"string","name":"","type":"string"}],"stateMutability":"view","type":"function"},{"inputs":[],"name":"totalSupply","outputs":[{"internalType":"uint256","name":"","type":"uint256"}],"stateMutability":"view","type":"function"},{"inputs":[{"internalType":"address","name":"recipient","type":"address"},{"internalType":"uint256","name":"amount","type":"uint256"}],"name":"transfer","outputs":[{"internalType":"bool","name":"","type":"bool"}],"stateMutability":"nonpayable","type":"function"},{"inputs":[{"internalType":"address","name":"sender","type":"address"},{"internalType":"address","name":"recipient","type":"address"},{"internalType":"uint256","name":"amount","type":"uint256"}],"name":"transferFrom","outputs":[{"internalType":"bool","name":"","type":"bool"}],"stateMutability":"nonpayable","type":"function"}]';

apeCoinAddr='0x4d224452801ACEd8B2F0aebE155379bb5D594381';

var contract=new web3.eth.Contract(JSON.parse(abi), apeCoinAddr);


kafkaConfigMap={'bootstrap.servers':'localhost:9092', 'dr_msg_cb':true};

function createProducer(onDeliveryReport) {

  const producer = new Kafka.Producer(kafkaConfigMap);

  return new Promise((resolve, reject) => {
    producer
      .on('ready', () => resolve(producer))
      .on('delivery-report', onDeliveryReport)
      .on('event.error', (err) => {
        console.warn('event.error', err);
        reject(err);
      });
    producer.connect();
  });
} 

var partition=-1;
var producer;

//the "transfer" topic needs to be created on kafka
//$KAFKA_HOME/bin/kafka-topics.sh --create --topic transfer --bootstrap-server localhost:9092
async function eventProducer() {

    let topic="transfer";
    producer=await createProducer((err, report) => {
        if (err) console.warn('Error producing', err);
        else {
            const {topic, key, value} = report;
            let k = key.toString().padEnd(10, ' ');
            console.log(`Produced event to topic ${topic}: key = ${k} value = ${value}`);            
        }
    });
    contract.events.Transfer({}, function(error, event) {
        if (error) console.warn('Event error', error);
        else {
            producer.produce(topic, partition, Buffer.from([Date.now().toString(), event.returnValues.from, event.returnValues.to, event.returnValues.value].join(':')), "transfer");
        }    
    });
}   

eventProducer().catch((err)=>{console.warn(err)});

