const { ethers } = require("ethers");
const constants = require("./constants");

function main() {
  const abiCoder = ethers.utils.defaultAbiCoder;

  const swapExactInput = abiCoder.encode(
    ["address", "uint256", "uint256", "bytes", "bool"],
    [
      // "0x2e234DAe75C793f67A35089C9d99245E1C58470b",
      constants.UNIVERSAL_ROUTER_ADDRESS,
      40000000,
      constants.MINIMUM_OUT,
      ethers.utils.solidityPack(
        ["address", "uint24", "address"],
        [
          constants.USDC_ADDRESS,
          constants.UNIV3_WETH_USDC_POOL_FEE,
          constants.USDT_ADDRESS,
        ],
      ),
      true,
    ],
  );

  const payPortion = abiCoder.encode(
    ["address", "address", "uint256"],
    [
      constants.USDT_ADDRESS,
      "0xFBFf93ae6Ef22688cf9C40fCda25d3A2C617F918",
      constants.FEE_BIPS,
    ],
  );

  const payPortionSecond = abiCoder.encode(
    ["address", "address", "uint256"],
    [
      constants.USDT_ADDRESS,
      "0x2e234DAe75C793f67A35089C9d99245E1C58470b",
      BigInt(10000),
    ],
  );

  const swapExactInputExecutorAsRecipient = abiCoder.encode(
    ["address", "uint256", "uint256", "bytes", "bool"],
    [
      "0x2e234DAe75C793f67A35089C9d99245E1C58470b",
      // "0x66a9893cC07D91D95644AEDD05D03f95e1dBA8Af",
      40000000,
      constants.MINIMUM_OUT,
      ethers.utils.solidityPack(
        ["address", "uint24", "address"],
        [
          constants.USDC_ADDRESS,
          constants.UNIV3_WETH_USDC_POOL_FEE,
          constants.USDT_ADDRESS,
        ],
      ),
      true,
    ],
  );

  //! We logged these values in order to pass them as data to universal contract call.

  console.log(swapExactInput.slice(2));
  console.log("#######################################");
  console.log(payPortion.slice(2));
  console.log("@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@");
  console.log(payPortionSecond.slice(2));
  console.log("********************************");
  console.log(swapExactInputExecutorAsRecipient.slice(2));
}

main();
