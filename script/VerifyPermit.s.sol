// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import 'forge-std/console2.sol';
import 'forge-std/Script.sol';
import {RouterParameters} from 'contracts/base/RouterImmutables.sol';
import {UnsupportedProtocol} from 'contracts/deploy/UnsupportedProtocol.sol';
import {UniversalRouter} from 'contracts/UniversalRouter.sol';
import {Permit2} from 'permit2/src/Permit2.sol';
import {ERC20PresetMinterPauser} from '@openzeppelin/contracts/token/ERC20/presets/ERC20PresetMinterPauser.sol';

contract VerifyablePermit2 is Permit2 {}

contract VerifyPermitDeploy is Script {
    function setUp() public {
        ERC20PresetMinterPauser token = new ERC20PresetMinterPauser('t', 'T');
        VerifyablePermit2 permit2 = new VerifyablePermit2();

        console2.log('token', address(token));
        console2.log('permit2', address(permit2));
    }

    function run() external {}
}

contract VerifyPermit is Script {
    address token;
    address permit2;
    address who;
    uint256 amount;

    function setUp() public {
        who = vm.envAddress('WHO');
        amount = vm.envUint('AMOUNT');
        token = vm.envAddress('TOKEN');
        permit2 = vm.envAddress('PERMIT2');
    }

    function run() external {
        ERC20PresetMinterPauser(token).mint(who, amount);
        ERC20PresetMinterPauser(token).transferFrom(who, permit2, amount);

        console2.log(ERC20PresetMinterPauser(token).balanceOf(permit2));
    }
}
