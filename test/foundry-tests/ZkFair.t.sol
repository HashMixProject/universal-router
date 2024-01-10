// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import 'forge-std/Test.sol';
import 'forge-std/Vm.sol';

import {Permit2} from 'permit2/src/Permit2.sol';
import {IAllowanceTransfer} from 'permit2/src/interfaces/IAllowanceTransfer.sol';
import {PermitHash} from 'permit2/src/libraries/PermitHash.sol';
import {EIP712} from 'permit2/src/EIP712.sol';
import {ERC20} from 'solmate/src/tokens/ERC20.sol';
import {IUniswapV2Factory} from '@uniswap/v2-core/contracts/interfaces/IUniswapV2Factory.sol';
import {IUniswapV2Pair} from '@uniswap/v2-core/contracts/interfaces/IUniswapV2Pair.sol';
import {UniversalRouter} from '../../contracts/UniversalRouter.sol';
import {Payments} from '../../contracts/modules/Payments.sol';
import {Constants} from '../../contracts/libraries/Constants.sol';
import {Commands} from '../../contracts/libraries/Commands.sol';
import {RouterParameters} from '../../contracts/base/RouterImmutables.sol';

import '@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol';
import '@openzeppelin/contracts/token/ERC1155/IERC1155Receiver.sol';

abstract contract ZkFair is Test {
    using PermitHash for IAllowanceTransfer.PermitSingle;

    address constant RECIPIENT = address(10);
    uint256 constant AMOUNT = 1 ether;
    uint256 constant BALANCE = 100000 ether;
    // IUniswapV2Factory constant factory = IUniswapV2Factory();
    // ERC20 constant WETH9 = ERC20(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);
    // Permit2 constant PERMIT2 = Permit2(0x000000000022D473030F116dDEE9F6B43aC78BA3);

    address FROM;
    uint256 FROM_Priv;

    UniversalRouter router;
    IUniswapV2Factory factory;
    Permit2 permit2;

    IUniswapV2Pair pairToken0Token1;
    IUniswapV2Pair pairToken1Token2;
    IUniswapV2Pair pairToken2Token3;
    IUniswapV2Pair pairToken0Token3;

    function setUp() public virtual {
        // vm.createSelectFork(vm.envString('FORK_URL'), 16000000);
        //
        //
        (FROM, FROM_Priv) = makeAddrAndKey('1234');
        setUpTokens();

        address _f = deployCode('UniswapV2Factory.sol:UniswapV2Factory', abi.encode(address(0)));
        factory = IUniswapV2Factory(_f);
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
        address pair1 = factory.createPair(token0(), token1());
        deal(token0(), pair1, 100 ether);
        deal(token1(), pair1, 100 ether);
        IUniswapV2Pair(pair1).sync();
        pairToken0Token1 = IUniswapV2Pair(pair1);

        address pair2 = factory.createPair(token1(), token2());
        deal(token1(), pair2, 100 ether);
        deal(token2(), pair2, 100 ether);
        IUniswapV2Pair(pair2).sync();
        pairToken1Token2 = IUniswapV2Pair(pair2);

        address pair3 = factory.createPair(token2(), token3());
        deal(token2(), pair3, 100 ether);
        deal(token3(), pair3, 100 ether);
        IUniswapV2Pair(pair3).sync();
        pairToken2Token3 = IUniswapV2Pair(pair3);

        address pair4 = factory.createPair(token0(), token3());
        deal(token0(), pair4, 100 ether);
        deal(token3(), pair4, 100 ether);
        IUniswapV2Pair(pair4).sync();
        pairToken0Token3 = IUniswapV2Pair(pair4);

        vm.startPrank(FROM);
        deal(FROM, BALANCE);
        deal(token0(), FROM, BALANCE);
        deal(token1(), FROM, BALANCE);
        deal(token2(), FROM, BALANCE);
        deal(token3(), FROM, BALANCE);
        ERC20(token0()).approve(address(permit2), type(uint256).max);
        ERC20(token1()).approve(address(permit2), type(uint256).max);
        ERC20(token2()).approve(address(permit2), type(uint256).max);
        ERC20(token3()).approve(address(permit2), type(uint256).max);
        // permit2.approve(token0(), address(router), type(uint160).max, type(uint48).max);
        //        permit2.approve(token1(), address(router), type(uint160).max, type(uint48).max);
        //        permit2.approve(token2(), address(router), type(uint160).max, type(uint48).max);
        //        permit2.approve(token3(), address(router), type(uint160).max, type(uint48).max);
    }

    function testExactInput0For1For2For3() public {
        bytes memory commands = abi.encodePacked(
            bytes1(uint8(Commands.PERMIT2_PERMIT)),
            bytes1(uint8(Commands.V2_SWAP_EXACT_IN))
        );

        (, , uint48 nonce) = permit2.allowance(FROM, token0(), address(router));

        IAllowanceTransfer.PermitSingle memory permitSingle = IAllowanceTransfer.PermitSingle({
            details: IAllowanceTransfer.PermitDetails({
                token: token0(),
                amount: uint160(AMOUNT),
                expiration: uint48(block.timestamp + 1000),
                nonce: nonce
            }),
            spender: address(router),
            sigDeadline: block.timestamp + 1000
        });

        bytes32 digest = keccak256(abi.encodePacked('\x19\x01', permit2.DOMAIN_SEPARATOR(), permitSingle.hash()));
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(FROM_Priv, digest);
        bytes memory signature = abi.encodePacked(r, s, v);

        bytes memory commandsData0 = abi.encode(permitSingle, signature);
        bytes memory path = abi.encodePacked(
            token0(),
            pairToken0Token1,
            uint16(50),
            token1(),
            pairToken1Token2,
            uint16(40),
            token2(),
            pairToken2Token3,
            uint16(30),
            token3()
        );

        bytes[] memory inputs = new bytes[](2);
        inputs[0] = commandsData0;
        inputs[1] = abi.encodePacked(Constants.MSG_SENDER, AMOUNT, uint256(0), true, path);

        router.execute(commands, inputs);

        assertEq(ERC20(token0()).balanceOf(FROM), BALANCE - AMOUNT);
        assertGt(ERC20(token3()).balanceOf(FROM), BALANCE);
    }

    function testExactInput0For3_0For1For2For3() public {
        (, , uint48 nonce) = permit2.allowance(FROM, token0(), address(router));

        IAllowanceTransfer.PermitSingle memory permitSingle = IAllowanceTransfer.PermitSingle({
            details: IAllowanceTransfer.PermitDetails({
                token: token0(),
                amount: uint160(AMOUNT * 2),
                expiration: uint48(block.timestamp + 1000),
                nonce: nonce
            }),
            spender: address(router),
            sigDeadline: block.timestamp + 1000
        });

        bytes32 digest = keccak256(abi.encodePacked('\x19\x01', permit2.DOMAIN_SEPARATOR(), permitSingle.hash()));
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(FROM_Priv, digest);
        bytes memory signature = abi.encodePacked(r, s, v);

        bytes memory commands = abi.encodePacked(
            bytes1(uint8(Commands.PERMIT2_PERMIT)),
            bytes1(uint8(Commands.V2_SWAP_EXACT_IN)),
            bytes1(uint8(Commands.V2_SWAP_EXACT_IN))
        );
        bytes[] memory commandsData = new bytes[](3);
        commandsData[0] = abi.encode(permitSingle, signature);

        bytes memory path = abi.encodePacked(token0(), pairToken0Token3, uint16(50), token3());
        commandsData[1] = abi.encodePacked(Constants.MSG_SENDER, AMOUNT, uint256(0), true, path);

        bytes memory path2 = abi.encodePacked(
            token0(),
            pairToken0Token1,
            uint16(50),
            token1(),
            pairToken1Token2,
            uint16(40),
            token2(),
            pairToken2Token3,
            uint16(30),
            token3()
        );

        commandsData[2] = abi.encodePacked(Constants.MSG_SENDER, AMOUNT, uint256(0), true, path2);

        uint256 token1Balance = ERC20(token1()).balanceOf(FROM);

        router.execute(commands, commandsData);
        assertEq(ERC20(token0()).balanceOf(FROM), BALANCE - AMOUNT * 2);
        assertGt(ERC20(token3()).balanceOf(FROM), BALANCE);
        assertEq(ERC20(token1()).balanceOf(FROM), token1Balance);
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
