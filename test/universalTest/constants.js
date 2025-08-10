"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.MINIMUM_OUT =
  exports.CONTRACT_BALANCE_SPECIAL_VALUE =
  exports.PAY_PORTION_COMMAND =
  exports.SWEEP_COMMAND =
  exports.PERMIT2_TRANSFER_FROM_COMMAND =
  exports.SWAP_EXACT_INPUT_COMMAND =
  exports.FEE_RECIPIENT =
  exports.FEE_BIPS =
  exports.AMOUNT_IN =
  exports.UNIV3_WETH_USDC_POOL_FEE =
  exports.USDT_ADDRESS =
  exports.USDC_ADDRESS =
  exports.WETH_ADDRESS =
  exports.PERMIT2_ADDRESS =
  exports.UNIVERSAL_ROUTER_ADDRESS =
  exports.PRIVATE_KEY =
  exports.RPC_URL =
    void 0;
// Assume we're using a forked network (e.g. anvil --fork-url ... )
exports.RPC_URL = "http://localhost:8545";
// We'll use hardhat test wallet 0
exports.PRIVATE_KEY =
  "0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80";
// Addresses we'll need
exports.UNIVERSAL_ROUTER_ADDRESS = "0x66a9893cC07D91D95644AEDD05D03f95e1dBA8Af";
exports.PERMIT2_ADDRESS = "0x000000000022d473030f116ddee9f6b43ac78ba3";
exports.WETH_ADDRESS = "0xc02aaa39b223fe8d0a0e5c4f27ead9083c756cc2";
exports.USDC_ADDRESS = "0xa0b86991c6218b36c1d19d4a2e9eb0ce3606eb48"; // USDC
exports.USDT_ADDRESS = "0xdAC17F958D2ee523a2206206994597C13D831ec7"; // USDT
// We'll need to the pool fee for our path. This is 0.05%.
exports.UNIV3_WETH_USDC_POOL_FEE = BigInt(500);
// Let's say we're swapping 1 WETH for USDC
exports.AMOUNT_IN = BigInt(1e18);
// Let's take 1% of every transaction before swap and send it to an address
exports.FEE_BIPS = BigInt(500); // 1.23%
exports.FEE_RECIPIENT = "0x8A37ab849Dd795c0CA1979b7fcA24F90Be95d618";
// See https://github.com/Uniswap/universal-router/blob/main/contracts/libraries/Commands.sol
exports.SWAP_EXACT_INPUT_COMMAND = 0x00;
exports.PERMIT2_TRANSFER_FROM_COMMAND = 0x02;
exports.SWEEP_COMMAND = 0x04;
exports.PAY_PORTION_COMMAND = 0x06;
// This is a special value that tells the router to use the contract's total balance
// of a given token.
// https://github.com/Uniswap/universal-router/blob/1cde151b29f101cb06c0db4a2afededa864307b3/contracts/libraries/Constants.sol#L9-L11
exports.CONTRACT_BALANCE_SPECIAL_VALUE =
  BigInt(0x8000000000000000000000000000000000000000000000000000000000000000);
// For a real use case this should be an accurate minimum
// You can get this from Uniswap's quoter, a TWAP, another oracle, etc.
exports.MINIMUM_OUT = 0;
