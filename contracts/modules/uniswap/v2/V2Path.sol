// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity >=0.6.0;

library V2Path {
    function decodePathByIndex(
        bytes calldata input,
        uint256 paramsOffset,
        uint256 i
    ) internal pure returns (address tokenFrom, address pair, uint16 fee, address tokenTo) {
        uint pathCount = size(input, paramsOffset);
        if (i >= pathCount) {
            revert('OOM');
        }

        assembly {
            let indexOffset := add(paramsOffset, mul(i, 0x2A))
            tokenFrom := shr(96, calldataload(add(indexOffset, input.offset)))
            pair := shr(96, calldataload(add(indexOffset, add(input.offset, 0x14))))
            fee := shr(240, calldataload(add(indexOffset, add(input.offset, 0x28))))
            tokenTo := shr(96, calldataload(add(indexOffset, add(input.offset, 0x2A))))
        }
    }

    function decodePathLast(
        bytes calldata input,
        uint256 paramsOffset
    ) internal pure returns (address tokenFrom, address pair, uint16 fee, address tokenTo) {
        uint256 l = size(input, paramsOffset);
        return decodePathByIndex(input, paramsOffset, l - 1);
    }

    function size(bytes calldata input, uint256 paramsOffset) internal pure returns (uint256 l) {
        uint256 inputLen = input.length;

        assembly {
            let xxx := sub(inputLen, paramsOffset)
            if iszero(eq(mod(sub(xxx, 0x14), 0x2A), 0)) {
                revert(0, 0)
            }
            l := div(sub(xxx, 0x14), 0x2A)
        }
    }
}
