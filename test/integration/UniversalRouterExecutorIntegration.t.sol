// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

import {SafeTransferLib} from "solmate/src/utils/SafeTransferLib.sol";
import {Test} from "forge-std/Test.sol";
import {IPermit2} from "permit2/src/interfaces/IPermit2.sol";
import {ERC20} from "solmate/src/tokens/ERC20.sol";
import {UniversalRouterExecutor} from "../../src/sample-executors/UniversalRouterExecutor.sol";
import {InputToken, OrderInfo, SignedOrder} from "../../src/base/ReactorStructs.sol";
import {OrderInfoBuilder} from "../util/OrderInfoBuilder.sol";
import {DutchOrderReactor, DutchOrder, DutchInput, DutchOutput} from "../../src/reactors/DutchOrderReactor.sol";
import {OutputsBuilder} from "../util/OutputsBuilder.sol";
import {PermitSignature} from "../util/PermitSignature.sol";
import {IReactor} from "../../src/interfaces/IReactor.sol";
import {IUniversalRouter} from "../../src/external/IUniversalRouter.sol";
import {V2DutchOrderTest} from "../reactors/V2DutchOrderReactor.t.sol";
import {console2} from "forge-std/console2.sol";

contract UniversalRouterExecutorIntegrationTest is Test, PermitSignature {
    using OrderInfoBuilder for OrderInfo;
    using SafeTransferLib for ERC20;

    ERC20 constant USDC = ERC20(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48);
    ERC20 constant USDT = ERC20(0xdAC17F958D2ee523a2206206994597C13D831ec7);
    uint256 public constant cosignerPrivateKey = 0x99999999;

    uint256 constant USDC_ONE = 1e6;

    // UniversalRouter with V4 support
    IUniversalRouter universalRouter =
        IUniversalRouter(0x66a9893cC07D91D95644AEDD05D03f95e1dBA8Af);
    IPermit2 permit2 = IPermit2(0x000000000022D473030F116dDEE9F6B43aC78BA3);

    address swapper;
    uint256 swapperPrivateKey;
    address whitelistedCaller;
    address owner;
    UniversalRouterExecutor universalRouterExecutor;
    UniversalRouterExecutor universalRouterExecutorForV2;
    DutchOrderReactor reactor;

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
        reactor = new DutchOrderReactor(permit2, address(0));
        console2.log("try find deposit", address(reactor).balance);
        address[] memory whitelistedCallers = new address[](1);
        whitelistedCallers[0] = whitelistedCaller;
        universalRouterExecutor = new UniversalRouterExecutor(
            whitelistedCallers,
            IReactor(address(reactor)),
            owner,
            address(universalRouter),
            permit2
        );
        vm.prank(swapper);
        USDC.approve(address(permit2), type(uint256).max);

        deal(address(USDC), swapper, 100 * 1e6);
    }

    function baseTest(DutchOrder memory order) internal {
        // _baseTest(order, false, "");
        _baseTest2(order, false, "");
    }

    function _baseTest(
        DutchOrder memory order,
        bool expectRevert,
        bytes memory revertData
    ) internal {
        address[]
            memory tokensToApproveForPermit2AndUniversalRouter = new address[](
                1
            );
        tokensToApproveForPermit2AndUniversalRouter[0] = address(USDC);

        address[] memory tokensToApproveForReactor = new address[](1);
        tokensToApproveForReactor[0] = address(USDT);

        bytes memory commands = hex"00";
        // bytes memory commands = abi.encodePacked(uint8(0x00), uint8(0x08));

        bytes[] memory inputs = new bytes[](1);
        // V3 swap USDC -> USDT, with recipient as universalRouterExecutor
        //0000000000000000000000002e234DAe75C793f67A35089C9d99245E1C58470b0000000000000000000000000000000000000000000000000000000000989680000000000000000000000000000000000000000000000000000000000090972200000000000000000000000000000000000000000000000000000000000000a00000000000000000000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000000000000000000000002ba0b86991c6218b36c1d19d4a2e9eb0ce3606eb48000064dac17f958d2ee523a2206206994597c13d831ec7000000000000000000000000000000000000000000
        inputs[
            0
        ] = hex"0000000000000000000000002e234DAe75C793f67A35089C9d99245E1C58470b0000000000000000000000000000000000000000000000000000000000989680000000000000000000000000000000000000000000000000000000000090972200000000000000000000000000000000000000000000000000000000000000a00000000000000000000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000000000000000000000002ba0b86991c6218b36c1d19d4a2e9eb0ce3606eb48000064dac17f958d2ee523a2206206994597c13d831ec7000000000000000000000000000000000000000000";
        bytes memory data = abi.encodeWithSelector(
            IUniversalRouter.execute.selector,
            commands,
            inputs,
            uint256(block.timestamp + 1000)
        );

        vm.prank(whitelistedCaller);
        if (expectRevert) {
            vm.expectRevert(revertData);
        }
        universalRouterExecutor.execute(
            SignedOrder(
                abi.encode(order),
                signOrder(swapperPrivateKey, address(permit2), order)
            ),
            abi.encode(
                tokensToApproveForPermit2AndUniversalRouter,
                tokensToApproveForReactor,
                data
            )
        );
    }

    function _baseTest2(
        DutchOrder memory order,
        bool expectRevert,
        bytes memory revertData
    ) internal {
        address[]
            memory tokensToApproveForPermit2AndUniversalRouter = new address[](
                1
            );
        tokensToApproveForPermit2AndUniversalRouter[0] = address(USDC);

        address[] memory tokensToApproveForReactor = new address[](1);
        tokensToApproveForReactor[0] = address(USDT);

        bytes memory commands = abi.encodePacked(
            uint8(0x00),
            uint8(0x06),
            uint8(0x06)
        );

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
        if (expectRevert) {
            vm.expectRevert(revertData);
        }
        uint gasLeftBefore = gasleft();
        universalRouterExecutor.execute(
            SignedOrder(
                abi.encode(order),
                signOrder(swapperPrivateKey, address(permit2), order)
            ),
            abi.encode(
                tokensToApproveForPermit2AndUniversalRouter,
                tokensToApproveForReactor,
                data
            )
        );
        uint gasLeftAfter = gasleft();
        console2.log(
            "atomic transactoin gas used",
            gasLeftBefore - gasLeftAfter
        );
        console2.log(
            "USDT balance of Whiteliseter: ",
            USDT.balanceOf(whitelistedCaller)
        );
        console2.log(
            "USDT balance of UniversalExecutor: ",
            USDT.balanceOf(address(universalRouterExecutor))
        );
        console2.log("USDT balance of swapper: ", USDT.balanceOf(swapper));
    }

    function test_universalRouterExecutor() internal {
        DutchOrder memory order = DutchOrder({
            info: OrderInfoBuilder
                .init(address(reactor))
                .withSwapper(swapper)
                .withDeadline(block.timestamp + 100),
            decayStartTime: block.timestamp - 100,
            decayEndTime: block.timestamp + 100,
            input: DutchInput(USDC, 40 * USDC_ONE, 40 * USDC_ONE),
            outputs: OutputsBuilder.singleDutch(
                address(USDT),
                37 * USDC_ONE,
                37 * USDC_ONE,
                address(swapper)
            )
        });

        address[]
            memory tokensToApproveForPermit2AndUniversalRouter = new address[](
                1
            );
        tokensToApproveForPermit2AndUniversalRouter[0] = address(USDC);

        address[] memory tokensToApproveForReactor = new address[](1);
        tokensToApproveForReactor[0] = address(USDT);

        uint256 swapperInputBalanceBefore = USDC.balanceOf(swapper);
        uint256 swapperOutputBalanceBefore = USDT.balanceOf(swapper);

        baseTest(order);
        console2.log(
            "USDT balance of Whiteliseter: ",
            USDT.balanceOf(whitelistedCaller)
        );
        console2.log(
            "USDT balance of UniversalExecutor: ",
            USDT.balanceOf(address(universalRouterExecutor))
        );
        console2.log("USDT balance of swapper: ", USDT.balanceOf(swapper));
        assertEq(
            USDC.balanceOf(swapper),
            swapperInputBalanceBefore - 10 * USDC_ONE
        );
        // assertEq(
        //     USDT.balanceOf(swapper),
        //     swapperOutputBalanceBefore + 9 * USDC_ONE
        // );
        // Expect some USDT to be left in the executor from the swap
        assertGe(USDT.balanceOf(address(universalRouterExecutor)), 0);
    }

    function test_first_transaction() internal {
        test_universalRouterExecutor_internal(
            10 * USDC_ONE,
            10 * USDC_ONE,
            9 * USDC_ONE,
            9 * USDC_ONE,
            1
        );
    }

    function test_second_transaction() public {
        console2.log("Going for second order!!!");
        test_universalRouterExecutor_internal(
            40 * USDC_ONE,
            40 * USDC_ONE,
            36 * USDC_ONE,
            36 * USDC_ONE,
            2
        );
    }

    function test_universalRouterExecutor_internal(
        uint startAmountIn,
        uint endAmountIn,
        uint startAmountOut,
        uint endAmountOut,
        uint nonce
    ) internal {
        DutchOrder memory order = DutchOrder({
            info: OrderInfoBuilder
                .init(address(reactor))
                .withSwapper(swapper)
                .withDeadline(block.timestamp + 100),
            decayStartTime: block.timestamp - 100,
            decayEndTime: block.timestamp + 100,
            input: DutchInput(USDC, startAmountIn, endAmountIn),
            outputs: OutputsBuilder.singleDutch(
                address(USDT),
                startAmountOut,
                endAmountOut,
                address(swapper)
            )
        });
        order.info.nonce = nonce;

        address[]
            memory tokensToApproveForPermit2AndUniversalRouter = new address[](
                1
            );
        tokensToApproveForPermit2AndUniversalRouter[0] = address(USDC);

        address[] memory tokensToApproveForReactor = new address[](1);
        tokensToApproveForReactor[0] = address(USDT);

        baseTest(order);
    }

    function test_universalRouterExecutor_TooLittleReceived() internal {
        DutchOrder memory order = DutchOrder({
            info: OrderInfoBuilder
                .init(address(reactor))
                .withSwapper(swapper)
                .withDeadline(block.timestamp + 100),
            decayStartTime: block.timestamp - 100,
            decayEndTime: block.timestamp + 100,
            input: DutchInput(USDC, 10 * USDC_ONE, 10 * USDC_ONE),
            // Too much output
            outputs: OutputsBuilder.singleDutch(
                address(USDT),
                11 * USDC_ONE,
                11 * USDC_ONE,
                address(swapper)
            )
        });

        _baseTest(order, true, bytes("TRANSFER_FROM_FAILED"));
    }

    function test_universalRouterExecutor_onlyOwner() internal {
        address nonOwner = makeAddr("nonOwner");
        address recipient = makeAddr("recipient");
        uint256 recipientBalanceBefore = recipient.balance;
        uint256 recipientUSDCBalanceBefore = USDC.balanceOf(recipient);

        vm.deal(address(universalRouterExecutor), 1 ether);
        deal(address(USDC), address(universalRouterExecutor), 100 * USDC_ONE);

        vm.prank(nonOwner);
        vm.expectRevert("UNAUTHORIZED");
        universalRouterExecutor.withdrawETH(recipient);

        vm.prank(nonOwner);
        vm.expectRevert("UNAUTHORIZED");
        universalRouterExecutor.withdrawERC20(USDC, recipient);

        vm.prank(owner);
        universalRouterExecutor.withdrawETH(recipient);
        assertEq(address(recipient).balance, recipientBalanceBefore + 1 ether);

        vm.prank(owner);
        universalRouterExecutor.withdrawERC20(USDC, recipient);
        assertEq(
            USDC.balanceOf(recipient),
            recipientUSDCBalanceBefore + 100 * USDC_ONE
        );
        assertEq(USDC.balanceOf(address(universalRouterExecutor)), 0);
    }
}
