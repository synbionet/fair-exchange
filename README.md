# Fair Exchange

## What is it?
Fair Exchange is a protocol to enable the exchange of goods and services on the Bionet. Overall, you can think of it as an escrow service, or trusted "middle-man", that ensures fees and assets are distributed as expected to the parties involved in an exchange. It uses incentives to encourage participants to follow the rules of the system to enforce atomic exchanges where *either both parties get what they expect, or none do*.

Our current effort is focused on a minimal viable product (MVP).  We're intentionally keeping the core logic as simple as possible as we work through the needs of the Synthetic Biology (SynBio) community.  

## Design
There are 3 main actors in the protocol: **buyer**, **seller**, and the **exchange**. A buyer and seller may want to exchange both digital and physical assets. The exchange contains the core logic and state machine. A state machine ensures the buyer and seller follow the rules of the system. Each state dictates the rewards and penalities that may impact the exchange.  The goal is to incentive participants to follow the rules.  And by following the rules, both parties get what they want, which helps to build trust in the system over time.

Buyers and sellers may exchange digital or physical assets (often referred to as *"phygitals"*), or a service.  The current state of SynBio often requires off-chain negotiation related to an exchange which can be time consuming. The protocol takes this into consideration and is being designed to help encourage participants to keep moving forward (through states) until the exchange is finalized.

See [docs](https://github.com/synbionet/doc.synbionet/blob/main/docs/contracts.md) from more information.

## Setup 
We use Foundry and VSCode (optional) as our smart contract development toolchain.
* Install Foundary: https://book.getfoundry.sh/getting-started/installation
* Install the Solidity plugin for VSCode: https://marketplace.visualstudio.com/items?itemName=JuanBlanco.solidity
* Clone this repository
* From this directory, run `forge install`

VSCode settings via `.vscode/setting.json`:
```json
{
  "solidity.packageDefaultDependenciesContractsDirectory": "src",
  "solidity.packageDefaultDependenciesDirectory": "lib",
  "search.exclude": {
    "lib": true
  },
  "solidity.defaultCompiler": "localFile",
  "solidity.formatter": "forge"
}
```
## Test
You can run all the tests with the following command:

```bash
 > make test
```
or via 

```bash 
> forge test --ffi -vv
```
Note the *--ffi* flag is needed to extract diamond function signatures.

## Build
For now we include the contract build files (json) in the repository (artifacts dir) so other projects can import the artifacts for use via `npm`.  However, this package is not yet published on `npm`, so install with `npm` using the github project URL:

`npm i https://github.com/synbionet/fair-exchange -S`

You can than get the `abi` and `bytecode` by importing the json file:

```js
import exchangefacetabi from "@synbionet/fair-exchange/artifacts/ExchangeFacet.json";
```

**Before commiting new contract code, run `make artifacts` to update the the json files**

## Deploy locally
To deploy to Anvil, run:
```bash
> make local_deploy
```
The deployed diamond address is logged to the console.

## Using simulator contracts
 TODO





