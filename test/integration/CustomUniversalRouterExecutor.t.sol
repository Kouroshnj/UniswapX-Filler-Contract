// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

import { SafeTransferLib } from "solmate/src/utils/SafeTransferLib.sol";
import { Test } from "forge-std/Test.sol";
import { IPermit2 } from "permit2/src/interfaces/IPermit2.sol";
import { ERC20 } from "solmate/src/tokens/ERC20.sol";
import { UniversalRouterExecutor } from "../../src/sample-executors/UniversalRouterExecutor.sol";
import { InputToken, OrderInfo, SignedOrder } from "../../src/base/ReactorStructs.sol";
import { OrderInfoBuilder } from "../util/OrderInfoBuilder.sol";
import {
    V2DutchOrder,
    V2DutchOrderLib,
    CosignerData,
    V2DutchOrderReactor,
    ResolvedOrder,
    DutchOutput,
    DutchInput,
    BaseReactor
} from "../../src/reactors/V2DutchOrderReactor.sol";
import { OutputsBuilder } from "../util/OutputsBuilder.sol";
import { DutchOrder } from "../../src/reactors/DutchOrderReactor.sol";
import { PermitSignature } from "../util/PermitSignature.sol";
import { IReactor } from "../../src/interfaces/IReactor.sol";
import { IUniversalRouter } from "../../src/external/IUniversalRouter.sol";
import { V2DutchOrderTest } from "../reactors/V2DutchOrderReactor.t.sol";
import { console2 } from "forge-std/console2.sol";
import { DutchDecayLib } from "../../src/lib/DutchDecayLib.sol";

contract UniversalRouterExecutorIntegrationTest is Test, PermitSignature {
    using OrderInfoBuilder for OrderInfo;
    using SafeTransferLib for ERC20;
    using V2DutchOrderLib for V2DutchOrder;
    using DutchDecayLib for DutchOutput[];
    using DutchDecayLib for DutchInput;

    ERC20 constant USDC = ERC20(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48);
    ERC20 constant USDT = ERC20(0xdAC17F958D2ee523a2206206994597C13D831ec7);
    uint256 public constant cosignerPrivateKey = 0x99999999;

    uint256 constant USDC_ONE = 1e6;

    // UniversalRouter with V4 support
    IUniversalRouter universalRouter = IUniversalRouter(0x66a9893cC07D91D95644AEDD05D03f95e1dBA8Af);
    IPermit2 permit2 = IPermit2(0x000000000022D473030F116dDEE9F6B43aC78BA3);

    address swapper;
    uint256 swapperPrivateKey;
    address whitelistedCaller;
    address owner;
    UniversalRouterExecutor universalRouterExecutor;
    UniversalRouterExecutor universalRouterExecutorForV2;
    V2DutchOrderReactor v2reactor;

    // UniversalRouter commands
    uint256 constant V3_SWAP_EXACT_IN = 0x00;

    function setUp() public {
        swapperPrivateKey = 0xbeef;
        swapper = vm.addr(swapperPrivateKey);
        vm.label(swapper, "swapper");
        whitelistedCaller = makeAddr("whitelistedCaller");
        owner = makeAddr("owner");
        // 02-10-2025
        vm.createSelectFork(vm.envString("FOUNDRY_RPC_URL"), 21818802);
        v2reactor = new V2DutchOrderReactor(permit2, address(0));
        address[] memory whitelistedCallers = new address[](1);
        whitelistedCallers[0] = whitelistedCaller;
        universalRouterExecutorForV2 = new UniversalRouterExecutor(
            whitelistedCallers,
            IReactor(address(v2reactor)),
            owner,
            address(universalRouter),
            permit2
        );
        vm.prank(swapper);
        USDC.approve(address(permit2), type(uint256).max);

        deal(address(USDC), swapper, 1000 * 1e6);
    }

    function test_two_outputs_in_order() public {
        DutchOutput[] memory result = new DutchOutput[](2);
        result[0] = DutchOutput(address(USDT), 37 * USDC_ONE, 37 * USDC_ONE, address(swapper));
        result[1] = DutchOutput(address(USDT), 2 * USDC_ONE, 2 * USDC_ONE, address(whitelistedCaller));
        DutchOrder memory order = DutchOrder({
            info: OrderInfoBuilder.init(address(v2reactor)).withSwapper(swapper).withDeadline(block.timestamp + 100),
            decayStartTime: block.timestamp - 100,
            decayEndTime: block.timestamp + 100,
            input: DutchInput(USDC, 40 * USDC_ONE, 40 * USDC_ONE),
            outputs: result
        });
        (SignedOrder memory signedOrder, ) = createAndSignDutchOrder(order);
        address[] memory tokensToApproveForPermit2AndUniversalRouter = new address[](1);
        tokensToApproveForPermit2AndUniversalRouter[0] = address(USDC);

        address[] memory tokensToApproveForReactor = new address[](1);
        tokensToApproveForReactor[0] = address(USDT);

        bytes memory commands = abi.encodePacked(uint8(0x00));

        bytes[] memory inputs = new bytes[](1);
        // V3 swap USDC -> USDT, with recipient as universalRouterExecutor
        //0000000000000000000000002e234DAe75C793f67A35089C9d99245E1C58470b0000000000000000000000000000000000000000000000000000000000989680000000000000000000000000000000000000000000000000000000000090972200000000000000000000000000000000000000000000000000000000000000a00000000000000000000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000000000000000000000002ba0b86991c6218b36c1d19d4a2e9eb0ce3606eb48000064dac17f958d2ee523a2206206994597c13d831ec7000000000000000000000000000000000000000000
        inputs[
            0
        ] = hex"0000000000000000000000002e234dae75c793f67a35089c9d99245e1c58470b0000000000000000000000000000000000000000000000000000000002625a00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000a00000000000000000000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000000000000000000000002ba0b86991c6218b36c1d19d4a2e9eb0ce3606eb480001f4dac17f958d2ee523a2206206994597c13d831ec7000000000000000000000000000000000000000000";
        bytes memory data = abi.encodeWithSelector(
            IUniversalRouter.execute.selector,
            commands,
            inputs,
            uint256(block.timestamp + 1000)
        );

        vm.prank(whitelistedCaller);
        uint gasLeftBefore = gasleft();
        universalRouterExecutorForV2.execute(
            signedOrder,
            abi.encode(tokensToApproveForPermit2AndUniversalRouter, tokensToApproveForReactor, data)
        );
        uint gasLeftAfter = gasleft();
        console2.log("Gas left In in two aoutputs method: ", gasLeftBefore - gasLeftAfter);
        console2.log("whitelisterBAlance", USDT.balanceOf(whitelistedCaller));
        console2.log("executor balance: ", USDT.balanceOf(address(universalRouterExecutorForV2)));
        //389337 gas consumed!
    }

    function test_wtihUniversalCommands() public {
        DutchOrder memory order = DutchOrder({
            info: OrderInfoBuilder.init(address(v2reactor)).withSwapper(swapper).withDeadline(block.timestamp + 100),
            decayStartTime: block.timestamp - 100,
            decayEndTime: block.timestamp + 100,
            input: DutchInput(USDC, 40 * USDC_ONE, 40 * USDC_ONE),
            outputs: OutputsBuilder.singleDutch(address(USDT), 37 * USDC_ONE, 37 * USDC_ONE, address(swapper))
        });
        (SignedOrder memory signedOrder, ) = createAndSignDutchOrder(order);
        address[] memory tokensToApproveForPermit2AndUniversalRouter = new address[](1);
        tokensToApproveForPermit2AndUniversalRouter[0] = address(USDC);

        address[] memory tokensToApproveForReactor = new address[](1);
        tokensToApproveForReactor[0] = address(USDT);

        bytes memory commands = abi.encodePacked(uint8(0x00), uint8(0x06), uint8(0x06));

        bytes[] memory inputs = new bytes[](3);
        // V3 swap USDC -> USDT, with recipient as universalRouterExecutor
        //0000000000000000000000002e234DAe75C793f67A35089C9d99245E1C58470b0000000000000000000000000000000000000000000000000000000000989680000000000000000000000000000000000000000000000000000000000090972200000000000000000000000000000000000000000000000000000000000000a00000000000000000000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000000000000000000000002ba0b86991c6218b36c1d19d4a2e9eb0ce3606eb48000064dac17f958d2ee523a2206206994597c13d831ec7000000000000000000000000000000000000000000
        inputs[
            0
        ] = hex"00000000000000000000000066a9893cc07d91d95644aedd05d03f95e1dba8af0000000000000000000000000000000000000000000000000000000002625a00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000a00000000000000000000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000000000000000000000002ba0b86991c6218b36c1d19d4a2e9eb0ce3606eb480001f4dac17f958d2ee523a2206206994597c13d831ec7000000000000000000000000000000000000000000";
        inputs[
            1
        ] = hex"000000000000000000000000dac17f958d2ee523a2206206994597c13d831ec7000000000000000000000000fbff93ae6ef22688cf9c40fcda25d3a2c617f91800000000000000000000000000000000000000000000000000000000000001f4";
        inputs[
            2
        ] = hex"000000000000000000000000dac17f958d2ee523a2206206994597c13d831ec70000000000000000000000002e234dae75c793f67a35089c9d99245e1c58470b0000000000000000000000000000000000000000000000000000000000002710";
        bytes memory data = abi.encodeWithSelector(
            IUniversalRouter.execute.selector,
            commands,
            inputs,
            uint256(block.timestamp + 1000)
        );

        vm.prank(whitelistedCaller);
        uint gasLeftBefore = gasleft();
        universalRouterExecutorForV2.execute(
            signedOrder,
            abi.encode(tokensToApproveForPermit2AndUniversalRouter, tokensToApproveForReactor, data)
        );
        uint gasLeftAfter = gasleft();
        console2.log("Gas left in Pay_portion method: ", gasLeftBefore - gasLeftAfter);
        //420992 gas consumed!
    }

    function createAndSignDutchOrder(
        DutchOrder memory request
    ) internal view returns (SignedOrder memory signedOrder, bytes32 orderHash) {
        uint256[] memory outputAmounts = new uint256[](request.outputs.length);
        for (uint256 i = 0; i < request.outputs.length; i++) {
            outputAmounts[i] = 0;
        }
        CosignerData memory cosignerData = CosignerData({
            decayStartTime: request.decayStartTime,
            decayEndTime: request.decayEndTime,
            exclusiveFiller: address(0),
            exclusivityOverrideBps: 0,
            inputAmount: 0,
            outputAmounts: outputAmounts
        });

        V2DutchOrder memory order = V2DutchOrder({
            info: request.info,
            cosigner: vm.addr(cosignerPrivateKey),
            baseInput: request.input,
            baseOutputs: request.outputs,
            cosignerData: cosignerData,
            cosignature: bytes("")
        });

        orderHash = order.hash();
        order.cosignature = cosignOrder(orderHash, cosignerData);
        return (SignedOrder(abi.encode(order), signOrder(swapperPrivateKey, address(permit2), order)), orderHash);
    }

    function cosignOrder(bytes32 orderHash, CosignerData memory cosignerData) private pure returns (bytes memory sig) {
        bytes32 msgHash = keccak256(abi.encodePacked(orderHash, abi.encode(cosignerData)));
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(cosignerPrivateKey, msgHash);
        sig = bytes.concat(r, s, bytes1(v));
    }

    function decode_signedOrder(
        SignedOrder memory signedOrder
    ) internal view returns (ResolvedOrder memory resolvedOrder) {
        signedOrder
            .order = "0x000000000000000000000000000000000000000000000000000000000000002000000000000000000000000000000000000000000000000000000000000001000000000000000000000000004449cd34d1eb1fedcf02a1be3834ffde8e6a6180000000000000000000000000514910771af9ca656af840dff83e8264ecf986ca00000000000000000000000000000000000000000000000f5fbc02959160c78c00000000000000000000000000000000000000000000000f5fbc02959160c78c00000000000000000000000000000000000000000000000000000000000001e00000000000000000000000000000000000000000000000000000000000000300000000000000000000000000000000000000000000000000000000000000042000000000000000000000000000000011f84b9aa48e5f8aa8b9897600006289be00000000000000000000000047354d298986326887f758361199ae6057bb17db0468328766cfeaa54cf04882b93444782401bf9dbf92a5350edb8f2265bf960500000000000000000000000000000000000000000000000000000000686a6e3a000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000c000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000002000000000000000000000000a0b86991c6218b36c1d19d4a2e9eb0ce3606eb4800000000000000000000000000000000000000000000000000000000de13a00300000000000000000000000000000000000000000000000000000000dc1ce8fd00000000000000000000000047354d298986326887f758361199ae6057bb17db000000000000000000000000a0b86991c6218b36c1d19d4a2e9eb0ce3606eb4800000000000000000000000000000000000000000000000000000000008e7c3b00000000000000000000000000000000000000000000000000000000008d39af00000000000000000000000027213e28d7fda5c57fe9e5dd923818dbccf71c4700000000000000000000000000000000000000000000000000000000686a6d3000000000000000000000000000000000000000000000000000000000686a6d6c000000000000000000000000ce79b081c0c924cb67848723ed3057234d10fc6b0000000000000000000000000000000000000000000000000000000000000064000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000c0000000000000000000000000000000000000000000000000000000000000000200000000000000000000000000000000000000000000000000000000de7352d80000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000004106ff1e3054642410d5e4e5cf4b8b384cff1dd805e785fd7c5c1e0ca1cc9271737a15b9ea935032f1dfdfcc5e8c9b2fbaa3687d3ec6a3d56b72f253d78544fd901c00000000000000000000000000000000000000000000000000000000000000";
        signedOrder
            .sig = "0x6b006e08427d5b62d5b513b49fcef64d001bcb4f1e45bc427ce0524d6e0b22ea76d4bb328261498c2abbb4055e020379f17e409509efe951d9258168909fed251c";
        V2DutchOrder memory order = abi.decode(signedOrder.order, (V2DutchOrder));
        bytes32 orderHash = order.hash();
        resolvedOrder = ResolvedOrder({
            info: order.info,
            input: order.baseInput.decay(order.cosignerData.decayStartTime, order.cosignerData.decayEndTime),
            outputs: order.baseOutputs.decay(order.cosignerData.decayStartTime, order.cosignerData.decayEndTime),
            sig: signedOrder.sig,
            hash: orderHash
        });
        return resolvedOrder;
    }
}
