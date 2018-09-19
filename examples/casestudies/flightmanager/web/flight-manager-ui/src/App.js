import React, { Component } from 'react';
import logo from './logo.png';
import './App.css';
import Web3 from 'web3';
import abi from './abi.json';

class App extends Component {

  constructor(props) {
    super(props)

    const contract = this.props.match.params.contract || ""
    
    this.state = {
      //address: '0x87241310eb87e470ea24b2b581d7e9e5d1080838',
      address: contract.startsWith("0x") ? contract : null,
      flightID: null,
      numRemainingSeats: null,
    };

    //this.web3 = new Web3(Web3.givenProvider || "https://ropsten.infura.io/");
    this.web3 = new Web3(Web3.givenProvider);
  }

  componentDidMount() {
    this.loadFlightInfo()
  }

  render() {
    return (
      <div className="App">
        <header className="App-header">
          <img src={logo} className="App-logo" alt="logo" />
        </header>
        <form onSubmit={(e) => this.onAddressSubmit(e)}>
          <label>
            {"Contract Address:  "}
            <input type="text" name="name" onChange={(e) => {this.setState({address: e.target.value})}} />
          </label>
          <input type="submit" value="Connect" />
        </form>
        { this.state.flightID && 
            <div>
              <h1> {"Flight " + this.state.flightID}</h1>
              <p> Status: {this.state.isOpen ? "OPEN" : "CANCELLED"}</p>
              <p> {"Remaining Seats: " + this.state.numRemainingSeats} </p>
              <p> Single Ticket: {this.web3.utils.fromWei(this.state.ticketPrice)} ETH (943.85 USD)</p>
              <button className="button" onClick={() => this.onBuy()}> Buy 1 Ticket </button>
              <button className="button" onClick={() => this.onCancelFlight()}> Cancel Flight </button>
              <button className="button" onClick={() => this.onRetrieveRefund()}> Retrieve Refund </button>
            </div>
        }
        { this.state.tx && 
          <div>
            <a href={"https://kovan.etherscan.io/tx/" + this.state.tx}> {"Ethereum transaction: " + this.state.tx} </a>
          </div>
        }
      </div>
    );
  }

  async onBuy() {
    const accounts = await this.web3.eth.getAccounts()
    try {
      await this.contract.methods.buy().send({from: accounts[0], value: this.web3.utils.toWei("2")})
        .on('transactionHash', (tx) => {this.setState({tx: tx})});
    } catch(e) {
      console.error(e)
    }
  }

  async onCancelFlight() {
    const accounts = await this.web3.eth.getAccounts()
    try {
      await this.contract.methods.cancelFlight().send({from: accounts[0]})
        .on('transactionHash', (tx) => {this.setState({tx: tx})});
    } catch(e) {
      console.error(e)
    }
  }

  async onRetrieveRefund() {
    const accounts = await this.web3.eth.getAccounts()
    try {
      await this.contract.methods.retrieveRefund().send({from: accounts[0]})
        .on('transactionHash', (tx) => {this.setState({tx: tx})});
    } catch(e) {
      console.error(e)
    }
  }

  onAddressSubmit(e) {
    e.preventDefault();
    window.location = this.state.address;
    this.loadFlightInfo();
  }

  async loadFlightInfo() {
    if (!this.state.address) {
      return
    }

    this.contract = new this.web3.eth.Contract(abi);
    this.contract.options.address = this.state.address;

    const flightID = await this.contract.methods.getFlightID().call()
    const numRemainingSeats = await this.contract.methods.getNumRemainingSeats().call().valueOf()
    const isOpen = await this.contract.methods.isFlightCancelled().call().valueOf() == 0
    console.log(await this.contract.methods.isFlightCancelled().call().valueOf())
    const ticketPrice = await this.contract.methods.getTicketPrice().call().valueOf()

    this.setState({
      flightID: this.web3.utils.hexToAscii(flightID),
      numRemainingSeats: numRemainingSeats,
      isOpen: isOpen,
      ticketPrice: ticketPrice
    })
  }
}

export default App;
