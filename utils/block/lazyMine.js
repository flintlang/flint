/ * 
	Thanks to Daniel Dean of Mindlink for the base of this script
        http://engineering.mindlinksoft.com/creating-a-private-ethereum-blockchain-and-using-it-as-a-model/
*/

function checkPendingTransactions() {
    poll()
    if (eth.getBlock("pending").transactions.length > 0) {
        if (eth.mining) return;

        console.log("Mining pending transactions...\n");
        miner.start(1);
    } else {
        if (!eth.mining) return;

        miner.stop();
        console.log("Mining stopped.\n");
    }
}

function poll() {
    setTimeout(checkPendingTransactions, 1000);
}

eth.filter("latest", checkPendingTransactions);
eth.filter("pending", checkPendingTransactions);
checkPendingTransactions();


