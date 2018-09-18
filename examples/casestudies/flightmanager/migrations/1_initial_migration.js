var FlightManager = artifacts.require("./FlightManager.sol")
const config = require('../config.js')

module.exports = function(deployer, network, accounts) {
  const flightID = web3.toHex("IC217")
  const admin = config.airlinePublicKey
  const ticketPrice = 2000000000000000000
  const numTickets = 240

  deployer.deploy(FlightManager, flightID, admin, ticketPrice, numTickets).then(() => {});
}

