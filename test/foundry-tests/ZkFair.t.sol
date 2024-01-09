// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import 'forge-std/Test.sol';
import {Permit2} from 'permit2/src/Permit2.sol';
import {ERC20} from 'solmate/src/tokens/ERC20.sol';
import {IUniswapV2Factory} from '@uniswap/v2-core/contracts/interfaces/IUniswapV2Factory.sol';
import {UniswapV2Factory} from '@uniswap/v2-core/contracts/UniswapV2Factory.sol';
import {IUniswapV2Pair} from '@uniswap/v2-core/contracts/interfaces/IUniswapV2Pair.sol';
import {UniversalRouter} from '../../contracts/UniversalRouter.sol';
import {Payments} from '../../contracts/modules/Payments.sol';
import {Constants} from '../../contracts/libraries/Constants.sol';
import {Commands} from '../../contracts/libraries/Commands.sol';
import {RouterParameters} from '../../contracts/base/RouterImmutables.sol';

import '@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol';
import '@openzeppelin/contracts/token/ERC1155/IERC1155Receiver.sol';

abstract contract UniswapV2Test is Test {
    address constant RECIPIENT = address(10);
    uint256 constant AMOUNT = 1 ether;
    uint256 constant BALANCE = 100000 ether;
    // IUniswapV2Factory constant FACTORY = IUniswapV2Factory(0x5C69bEe701ef814a2B6a3EDD4B1652CB9cc5aA6f);
    // ERC20 constant WETH9 = ERC20(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);
    // Permit2 constant PERMIT2 = Permit2(0x000000000022D473030F116dDEE9F6B43aC78BA3);

    address constant FROM = address(1234);

    UniversalRouter router;
    UniswapV2Factory factory;
    Permit2 permit2;

    IUniswapV2Pair pairToken0Token1;
    IUniswapV2Pair pairToken1Token2;

    function setUp() public virtual {
        vm.createSelectFork(vm.envString('FORK_URL'), 16000000);
        setUpTokens();

        factory = new UniswapV2Factory(address(0));
        permit2 = new Permit2();

        RouterParameters memory params = RouterParameters({
            permit2: address(permit2),
            weth9: address(0),
            seaportV1_5: address(0),
            seaportV1_4: address(0),
            openseaConduit: address(0),
            nftxZap: address(0),
            x2y2: address(0),
            foundation: address(0),
            sudoswap: address(0),
            elementMarket: address(0),
            nft20Zap: address(0),
            cryptopunks: address(0),
            looksRareV2: address(0),
            routerRewardsDistributor: address(0),
            looksRareRewardsDistributor: address(0),
            looksRareToken: address(0),
            v2Factory: address(0),
            v3Factory: address(0),
            pairInitCodeHash: bytes32(0),
            poolInitCodeHash: bytes32(0)
        });
        router = new UniversalRouter(params);

        // pair doesn't exist, make a mock one
        if (factory.getPair(token0(), token1()) == address(0)) {
            address pair = factory.createPair(token0(), token1());
            deal(token0(), pair, 100 ether);
            deal(token1(), pair, 100 ether);
            IUniswapV2Pair(pair).sync();
            pairToken0Token1 = IUniswapV2Pair(pair);
        }
        if (factory.getPair(token1(), token2()) == address(0)) {
            address pair = factory.createPair(token1(), token2());
            deal(token1(), pair, 100 ether);
            deal(token2(), pair, 100 ether);
            IUniswapV2Pair(pair).sync();
            pairToken1Token2 = IUniswapV2Pair(pair);
        }

        vm.startPrank(FROM);
        deal(FROM, BALANCE);
        deal(token0(), FROM, BALANCE);
        deal(token1(), FROM, BALANCE);
        deal(token2(), FROM, BALANCE);
        ERC20(token0()).approve(address(permit2), type(uint256).max);
        ERC20(token1()).approve(address(permit2), type(uint256).max);
        ERC20(token2()).approve(address(permit2), type(uint256).max);
        permit2.approve(token0(), address(router), type(uint160).max, type(uint48).max);
        permit2.approve(token1(), address(router), type(uint160).max, type(uint48).max);
        permit2.approve(token2(), address(router), type(uint160).max, type(uint48).max);
    }

    function testExactInput0For2() public {
        bytes memory commands = abi.encodePacked(bytes1(uint8(Commands.V2_SWAP_EXACT_IN)));
        bytes[] memory path = new bytes[](1);
        path[0] = abi.encodePacked(token0, pairToken0Token1, uint16(50), token1, pairToken1Token2, uint16(40), token2);

        bytes[] memory inputs = new bytes[](1);
        inputs[0] = abi.encodePacked(Constants.MSG_SENDER, AMOUNT, 0, true, path);

        router.execute(commands, inputs);
        assertEq(ERC20(token0()).balanceOf(FROM), BALANCE - AMOUNT);
        assertGt(ERC20(token2()).balanceOf(FROM), BALANCE);
    }

    //    function testExactInput1For0() public {
    //        bytes memory commands = abi.encodePacked(bytes1(uint8(Commands.V2_SWAP_EXACT_IN)));
    //        address[] memory path = new address[](2);
    //        path[0] = token1();
    //        path[1] = token0();
    //        bytes[] memory inputs = new bytes[](1);
    //        inputs[0] = abi.encode(Constants.MSG_SENDER, AMOUNT, 0, path, true);
    //
    //        router.execute(commands, inputs);
    //        assertEq(ERC20(token1()).balanceOf(FROM), BALANCE - AMOUNT);
    //        assertGt(ERC20(token0()).balanceOf(FROM), BALANCE);
    //    }

    //    function testExactInput0For1FromRouter() public {
    //        bytes memory commands = abi.encodePacked(bytes1(uint8(Commands.V2_SWAP_EXACT_IN)));
    //        deal(token0(), address(router), AMOUNT);
    //        address[] memory path = new address[](2);
    //        path[0] = token0();
    //        path[1] = token1();
    //        bytes[] memory inputs = new bytes[](1);
    //        inputs[0] = abi.encode(Constants.MSG_SENDER, AMOUNT, 0, path, false);
    //
    //        router.execute(commands, inputs);
    //        assertGt(ERC20(token1()).balanceOf(FROM), BALANCE);
    //    }
    //
    //    function testExactInput1For0FromRouter() public {
    //        bytes memory commands = abi.encodePacked(bytes1(uint8(Commands.V2_SWAP_EXACT_IN)));
    //        deal(token1(), address(router), AMOUNT);
    //        address[] memory path = new address[](2);
    //        path[0] = token1();
    //        path[1] = token0();
    //        bytes[] memory inputs = new bytes[](1);
    //        inputs[0] = abi.encode(Constants.MSG_SENDER, AMOUNT, 0, path, false);
    //
    //        router.execute(commands, inputs);
    //        assertGt(ERC20(token0()).balanceOf(FROM), BALANCE);
    //    }
    //
    //    function testExactOutput0For1() public {
    //        bytes memory commands = abi.encodePacked(bytes1(uint8(Commands.V2_SWAP_EXACT_OUT)));
    //        address[] memory path = new address[](2);
    //        path[0] = token0();
    //        path[1] = token1();
    //        bytes[] memory inputs = new bytes[](1);
    //        inputs[0] = abi.encode(Constants.MSG_SENDER, AMOUNT, type(uint256).max, path, true);
    //
    //        router.execute(commands, inputs);
    //        assertLt(ERC20(token0()).balanceOf(FROM), BALANCE);
    //        assertGe(ERC20(token1()).balanceOf(FROM), BALANCE + AMOUNT);
    //    }
    //
    //    function testExactOutput1For0() public {
    //        bytes memory commands = abi.encodePacked(bytes1(uint8(Commands.V2_SWAP_EXACT_OUT)));
    //        address[] memory path = new address[](2);
    //        path[0] = token1();
    //        path[1] = token0();
    //        bytes[] memory inputs = new bytes[](1);
    //        inputs[0] = abi.encode(Constants.MSG_SENDER, AMOUNT, type(uint256).max, path, true);
    //
    //        router.execute(commands, inputs);
    //        assertLt(ERC20(token1()).balanceOf(FROM), BALANCE);
    //        assertGe(ERC20(token0()).balanceOf(FROM), BALANCE + AMOUNT);
    //    }
    //
    //    function testExactOutput0For1FromRouter() public {
    //        bytes memory commands = abi.encodePacked(bytes1(uint8(Commands.V2_SWAP_EXACT_OUT)));
    //        deal(token0(), address(router), BALANCE);
    //        address[] memory path = new address[](2);
    //        path[0] = token0();
    //        path[1] = token1();
    //        bytes[] memory inputs = new bytes[](1);
    //        inputs[0] = abi.encode(Constants.MSG_SENDER, AMOUNT, type(uint256).max, path, false);
    //
    //        router.execute(commands, inputs);
    //        assertGe(ERC20(token1()).balanceOf(FROM), BALANCE + AMOUNT);
    //    }
    //
    //    function testExactOutput1For0FromRouter() public {
    //        bytes memory commands = abi.encodePacked(bytes1(uint8(Commands.V2_SWAP_EXACT_OUT)));
    //        deal(token1(), address(router), BALANCE);
    //        address[] memory path = new address[](2);
    //        path[0] = token1();
    //        path[1] = token0();
    //        bytes[] memory inputs = new bytes[](1);
    //        inputs[0] = abi.encode(Constants.MSG_SENDER, AMOUNT, type(uint256).max, path, false);
    //
    //        router.execute(commands, inputs);
    //        assertGe(ERC20(token0()).balanceOf(FROM), BALANCE + AMOUNT);
    //    }

    function token0() internal virtual returns (address);

    function token1() internal virtual returns (address);

    function token2() internal virtual returns (address);

    function token3() internal virtual returns (address);

    function setUpTokens() internal virtual {}
}
