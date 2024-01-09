// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import 'forge-std/Test.sol';
import {MockERC20} from '../mock/MockERC20.sol';
import {ZkFair} from '../ZkFair.t.sol';

contract V2MockZkFair is ZkFair {
    MockERC20 mockA;
    MockERC20 mockB;
    MockERC20 mockC;
    MockERC20 mockD;

    function setUpTokens() internal override {
        mockA = new MockERC20();
        mockB = new MockERC20();
        mockC = new MockERC20();
        mockD = new MockERC20();
    }

    function token0() internal view override returns (address) {
        return address(mockA);
    }

    function token1() internal view override returns (address) {
        return address(mockB);
    }

    function token2() internal view override returns (address) {
        return address(mockC);
    }

    function token3() internal view override returns (address) {
        return address(mockD);
    }
}
