// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import {Functions, FunctionsClient} from "./dev/functions/FunctionsClient.sol";
import {ConfirmedOwner} from "@chainlink/contracts/src/v0.8/ConfirmedOwner.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";
//import {console} from "hardhat/console.sol";

/**
 * @title Functions Consumer contract
 * @notice This contract is a demonstration of using Functions.
 * @notice NOT FOR PRODUCTION USE
 */
contract FunctionsConsumer is FunctionsClient, ConfirmedOwner, ERC20 {
  using Functions for Functions.Request;

  string public source = "var a=args[0],c={url:`https://legiswipe.com/.netlify/functions/redeam?address=${a}`},d=await Functions.makeHttpRequest(c),e=Math.round(d.data['quantity']);return Functions.encodeUint256(e);";
  uint64 subId;
  bytes32 public latestRequestId;
  bytes public latestResponse;
  bytes public latestError;
  mapping (bytes32 => address) public redeemRequest;

  event OCRResponse(bytes32 indexed requestId, bytes result, bytes err);

  /**
   * @notice Executes once when a contract is created to initialize state variables
   *
   * @param oracle - The FunctionsOracle contract
   */
  // https://github.com/protofire/solhint/issues/242
  // solhint-disable-next-line no-empty-blocks
  constructor(address oracle) FunctionsClient(oracle) ConfirmedOwner(msg.sender) ERC20("legiswipe", "LEGIS") {}

  function decimals() public view virtual override returns (uint8) {
    return 0;
  }

  function setSubId(uint64 _subId) onlyOwner public {
    subId = _subId;
  }

  /**
   * @notice Send a simple request
   *
   * @param receiver Address of the token redeemer account
   * @param gasLimit Maximum amount of gas used to call the client contract's `handleOracleFulfillment` function
   * @return Functions request ID
   */
  function executeRequest(
    address receiver,
    uint32 gasLimit
  ) public onlyOwner returns (bytes32) {
    require(subId != 0, "Subscription ID must be set before redeeming");

    Functions.Request memory req;
    req.initializeRequest(Functions.Location.Inline, Functions.CodeLanguage.JavaScript, source);
    string[] memory args = new string[](2);
    string memory receiverString = Strings.toHexString(receiver);
    args[0] = receiverString;
    req.addArgs(args);

    bytes32 assignedReqID = sendRequest(req, subId, gasLimit);
    redeemRequest[assignedReqID] = receiver;
    latestRequestId = assignedReqID;
    return assignedReqID;
  }

  /**
   * @notice Callback that is invoked once the DON has resolved the request or hit an error
   *
   * @param requestId The request ID, returned by sendRequest()
   * @param response Aggregated response from the user code
   * @param err Aggregated error from the user code or from the execution pipeline
   * Either response or error parameter will be set, but never both
   */
  function fulfillRequest(bytes32 requestId, bytes memory response, bytes memory err) internal override {
    latestResponse = response;
    latestError = err;
    address receiver = redeemRequest[requestId];
    uint256 amount = uint256(bytes32(response));

    super._mint(receiver, amount);
    emit OCRResponse(requestId, response, err);
  }

  /**
   * @notice Allows the Functions oracle address to be updated
   *
   * @param oracle New oracle address
   */
  function updateOracleAddress(address oracle) public onlyOwner {
    setOracle(oracle);
  }

  function addSimulatedRequestId(address oracleAddress, bytes32 requestId) public onlyOwner {
    addExternalRequest(oracleAddress, requestId);
  }
}
