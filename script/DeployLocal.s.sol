// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import 'forge-std/console2.sol';
import 'forge-std/Script.sol';
import {RouterParameters} from 'contracts/base/RouterImmutables.sol';
import {UnsupportedProtocol} from 'contracts/deploy/UnsupportedProtocol.sol';
import {UniversalRouter} from 'contracts/UniversalRouter.sol';
import {Permit2} from 'permit2/src/Permit2.sol';
import {ERC20PresetMinterPauser} from '@openzeppelin/contracts/token/ERC20/presets/ERC20PresetMinterPauser.sol';
import {IUniswapV2Factory} from '@uniswap/v2-core/contracts/interfaces/IUniswapV2Factory.sol';
import {IUniswapV2Pair} from '@uniswap/v2-core/contracts/interfaces/IUniswapV2Pair.sol';

contract README is Script {
    function run() external view {
        console2.log('1. set env USER = your account \n  2. run DeployTokensAndPairs \n  3. run DeployRouter');
    }
}

contract DeployTokensAndPairs is Script {
    function run() external {
        vm.startBroadcast();

        address user = vm.envAddress('USER');

        ERC20PresetMinterPauser token1 = new ERC20PresetMinterPauser('1', '1');
        ERC20PresetMinterPauser token2 = new ERC20PresetMinterPauser('2', '2');
        ERC20PresetMinterPauser token3 = new ERC20PresetMinterPauser('3', '3');
        ERC20PresetMinterPauser token4 = new ERC20PresetMinterPauser('4', '4');
        ERC20PresetMinterPauser token5 = new ERC20PresetMinterPauser('5', '5');

        console2.log('token1', address(token1));
        console2.log('token2', address(token2));
        console2.log('token3', address(token3));
        console2.log('token4', address(token4));
        console2.log('token5', address(token5));

        token1.mint(user, 10000 ether);
        console2.log('mint token1 to', user, 10000 ether);

        address _f = deployCode('UniswapV2Factory.sol:UniswapV2Factory', abi.encode(address(0)));
        IUniswapV2Factory factory = IUniswapV2Factory(_f);
        console2.log('factory', _f);

        address pair1 = factory.createPair(address(token1), address(token2));
        token1.mint(pair1, 1000 ether);
        token2.mint(pair1, 1000 ether);
        IUniswapV2Pair(pair1).sync();
        console2.log('pair_1to2', pair1);

        address pair2 = factory.createPair(address(token2), address(token3));
        token2.mint(pair2, 1000 ether);
        token3.mint(pair2, 1000 ether);
        IUniswapV2Pair(pair2).sync();
        console2.log('pair_2to3', pair2);

        address pair3 = factory.createPair(address(token3), address(token4));
        token3.mint(pair3, 1000 ether);
        token4.mint(pair3, 1000 ether);
        IUniswapV2Pair(pair3).sync();
        console2.log('pair_3to4', pair3);

        address pair4 = factory.createPair(address(token4), address(token5));
        token4.mint(pair4, 1000 ether);
        token5.mint(pair4, 1000 ether);
        IUniswapV2Pair(pair4).sync();
        console2.log('pair_4to5', pair4);

        address pair5 = factory.createPair(address(token1), address(token5));
        token1.mint(pair5, 1000 ether);
        token5.mint(pair5, 1000 ether);
        IUniswapV2Pair(pair5).sync();
        console2.log('pair_1to5', pair5);

        address pair6 = factory.createPair(address(token2), address(token5));
        token2.mint(pair6, 1000 ether);
        token5.mint(pair6, 1000 ether);
        IUniswapV2Pair(pair6).sync();
        console2.log('pair_2to5', pair6);
    }
}

contract DeployRouter is Script {
    function run() external {
        vm.startBroadcast();

        Permit2 permit2 = new Permit2();

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

        UniversalRouter router = new UniversalRouter(params);

        console2.log('permit2', address(permit2));
        console2.log('router', address(router));
    }
}
