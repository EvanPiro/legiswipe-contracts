# Legiswipe Contracts

This repository contains the contracts and chainlink function code necessary to run the legiswipe.com token redemption system and data exchange.

## Token Redemption System

When a voter votes on congressional bills via [legiswipe.com](https://legiswipe.com/), an off-chain record updates on AWS representing the quantity of bills voted on by voter filtered by a date range. The token redemption contract supports minting a quantity of ERC20 tokens based on the number of bills the voter has voted on since their last redemption. 

### Chainlink Functions Usage

Enter shell
```shell
npx env-enc set-pw
```

#### Deploying Function Consumer

Any Function Consumer contracts belong to the legiswipe protocol. 

```shell
npx hardhat functions-deploy-client --network ethereumSepolia --verify true
```

Deploy [FunctionsConsumer.sol](./contracts/FunctionsConsumer.sol) which is constructed to pointer to a pre-existing `functionsOracleProxy` address. The script also verifies the contract.


#### Registering Function Consumer

Multiple instances of `FunctionsConsumer` can be registered for 1 subscription.

```shell
npx hardhat functions-sub-create --network ethereumSepolia --amount 3 --contract 0x89d15124dF5D05Ab13b37B1f3474889F6904A038
```

1. Connect to existing [FunctionsBillingRegistry](contracts/dev/functions/FunctionsBillingRegistry.sol:FunctionsBillingRegistry) and [FunctionsOracle](contracts/dev/functions/FunctionsOracle.sol:FunctionsOracle).
2. Check if transacting wallet is allowed to use chainlink functions.
3. Create a subscription from `FunctionsBillingRegistry`.
4. Get the sub ID from the emitted event.
5. Connect to the `LinkToken` contract.
6. Ensure LINK amount to be sent is above the balance of sender
7. Send the LINK amount to the `FunctionsBillingRegistryProxy` along with the sub id.
8. Add `FunctionConsumer` deployed in previous in command to `FunctionsBillingRegistry`.
9. After transaction is confirmed, print out the info on the subscription stored by the `FunctionBillingRegistry`. This includes

An Example output would be
```shell
Created subscription with ID: 362
Owner: 0x1A22f8e327adD0320d7ea341dFE892e43bC60322
Balance: 3.0 LINK
1 authorized consumer contract:
[ '0x89d15124dF5D05Ab13b37B1f3474889F6904A038' ]
```

#### Using Function Consumer

```shell
npx hardhat functions-request --network ethereumSepolia --contract 0x89d15124dF5D05Ab13b37B1f3474889F6904A038 --subid 356
```

1. Connect to the `FunctionsConsumerContract` we deployed previously.
2. Connect to the `FunctionsOracleProxy`.
3. Get `FunctionsBillingRegistry` address from `FunctionsOracleProxy`.
4. Check the validity of the subscription id with `FunctionsBillingRegistry`.
5. Check if the contract registered with the subscription is the same as the `FunctionsConsumerContract` deployed previously.
6. Call `estimateCost` on `FunctionsConsumerContract` to find out how much LINK will be charged on the function call. This method is inherited from [FunctionsClient](contracts/dev/functions/FunctionsClient.sol).
```solidity
  /**
   * @notice Estimate the total cost that will be charged to a subscription to make a request: gas re-imbursement, plus DON fee, plus Registry fee
   * @param req The initialized Functions.Request
   * @param subscriptionId The subscription ID
   * @param gasLimit gas limit for the fulfillment callback
   * @return billedCost Cost in Juels (1e18) of LINK
   */
    function estimateCost(
        Functions.Request memory req,
        uint64 subscriptionId,
        uint32 gasLimit,
        uint256 gasPrice
    ) public view returns (uint96) {
        return s_oracle.estimateCost(subscriptionId, Functions.encodeCBOR(req), gasLimit, gasPrice);
    }
```
The payload of the `req` will be the data that contains the code.
```javascript
      [
        requestConfig.codeLocation,
        1, // SecretsLocation: Remote
        requestConfig.codeLanguage,
        requestConfig.source,
        requestConfig.secrets && Object.keys(requestConfig.secrets).length > 0 ? simulatedSecretsURLBytes : [],
        requestConfig.args ?? [],
      ]
```

This object can be found in [Functions-request-config.js](Functions-request-config.js):
```javascript
const requestConfig = {
  // Location of source code (only Inline is currently supported)
  codeLocation: Location.Inline,
  // Code language (only JavaScript is currently supported)
  codeLanguage: CodeLanguage.JavaScript,
  // String containing the source code to be executed
  source: fs.readFileSync("./Functions-request-source-API-example.js").toString(),
  // Secrets can be accessed within the source code with `secrets.varName` (ie: secrets.apiKey). The secrets object can only contain string values. Following secrets are required - secretKey, accessKey
  secrets: {
    secretKey: process.env.SECRET_KEY,
    accessKey: process.env.ACCESS_KEY,
    dataSetID: process.env.DATASET_ID,
    revisionID: process.env.REVISION_ID,
    assetID: process.env.ASSET_ID
  },
  // Per-node secrets objects assigned to each DON member. When using per-node secrets, nodes can only use secrets which they have been assigned.
  perNodeSecrets: [],
  // ETH wallet key used to sign secrets so they cannot be accessed by a 3rd party
  walletPrivateKey: process.env["PRIVATE_KEY"],
  // args (string only array) can be accessed within the source code with `args[index]` (ie: args[0]).
  args: [
    "gbp",
    "usd"
  ],
  // expected type of the returned value
  expectedReturnType: ReturnType.int256,
  // Redundant URLs which point to encrypted off-chain secrets
  secretsURLs: [],
}
```
Observe that the `source` property points to a JS file [Functions-request-source-API-example.js](Functions-request-source-API-example.js). This file contains the code that the chainlink function will run offchain and pass the results to the `FunctionConsumer` contract. 
7. Call `estimateGas` on `FunctionConsumer`. This is similar to `estimateCost` but will return the gas.
You'll see a charge estimation prompt upon running this script:
```shell
Estimating cost if the current gas price remains the same...

The transaction to initiate this request will charge the wallet (0x1A22f8e327adD0320d7ea341dFE892e43bC60322):
0.000893206504763768 ETH, which (using mainnet value) is $0.0000030948126916901633

If the request's callback uses all 100,000 gas, this request will charge the subscription:
0.485248259962159355 LINK

Continue? Enter (y) Yes / (n) No
```
8. Call `executeRequest` on `FunctionConsumer`.

The run will produce the following logs if successful.
```shell
Simulating Functions request locally...

__Console log messages from sandboxed code__

__Output from sandboxed source code__
Output represented as a hex string: 0x000000000000000000000000000000000000000000000000000000000000007c
Decoded as a int256: 124

Successfully created encrypted secrets Gist: https://gist.github.com/EvanPiro/7d03f1f38f7468c8adde6057386093b3
ℹ Transaction confirmed, see https://sepolia.etherscan.io/tx/0x95330e02cc20c979025c9736a0daaac33a68e4e5a1b4dcb11bcefd1696506a64 for more details.
✔ Request 0x564ad34e069227b12cdb9f8126f19d2b64f60ae58d05964c571ca9dba6cb7e33 fulfilled! Data has been written on-chain.

Response returned to client contract represented as a hex string: 0x000000000000000000000000000000000000000000000000000000000000007c
Decoded as a int256: 124

Actual amount billed to subscription #362:
┌──────────────────────┬─────────────────────────────┐
│         Type         │           Amount            │
├──────────────────────┼─────────────────────────────┤
│  Transmission cost:  │  0.116829824904438415 LINK  │
│      Base fee:       │          0.2 LINK           │
│                      │                             │
│     Total cost:      │  0.316829824904438415 LINK  │
└──────────────────────┴─────────────────────────────┘


Off-chain secrets Gist https://gist.github.com/EvanPiro/7d03f1f38f7468c8adde6057386093b3 deleted successfully
```