init:
	geth --datadir . init ./genesis.json

run:
	geth --datadir ./blockchain --networkid 777 --ws --wsorigins "*" --wsapi="eth,web3,personal,miner" --gasprice 0

runH:
	geth --datadir . --networkid 777 --rpc --rpcapi="eth,web3,personal,miner,net,debug" --gasprice 0

attach:
	geth attach ws://localhost:8546

attachH:
	geth attach http://localhost:8545

script:
	geth attach ws://localhost:8546 --preload ./lazyMine.js

scriptH:
	geth attach http://localhost:8545 --preload ./lazyMine.js

clean:
	rm -rf blockchain/
	rm -rf ~/.ethash


