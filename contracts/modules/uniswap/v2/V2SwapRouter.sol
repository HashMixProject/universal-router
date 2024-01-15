// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.17;

import {IUniswapV2Pair} from '@uniswap/v2-core/contracts/interfaces/IUniswapV2Pair.sol';
import {Ownable} from '@openzeppelin/contracts/access/Ownable.sol';
import {UniswapV2Library} from './UniswapV2Library.sol';
import {UniswapImmutables} from '../UniswapImmutables.sol';
import {Payments} from '../../Payments.sol';
import {Permit2Payments} from '../../Permit2Payments.sol';
import {Constants} from '../../../libraries/Constants.sol';
import {ERC20} from 'solmate/src/tokens/ERC20.sol';
import {V2Path} from './V2Path.sol';

/// @title Router for Uniswap v2 Trades
abstract contract V2SwapRouter is UniswapImmutables, Permit2Payments, Ownable {
    error V2TooLittleReceived();
    error V2TooMuchRequested();
    error V2InvalidPath();

    using V2Path for bytes;

    uint256 v2_fee_bips = 0;

    function setFeeBips(uint256 _fee_bips) external onlyOwner {
        v2_fee_bips = _fee_bips;
    }

    function _v2Swap(bytes calldata input, uint256 bytesOffset, address recipient) private {
        unchecked {
            uint256 size = input.size(bytesOffset);

            for (uint256 i = 0; i < size; i++) {
                (address inToken, address pair, uint16 fee, address outToken) = input.decodePathByIndex(bytesOffset, i);
                (address token0, ) = UniswapV2Library.sortTokens(inToken, outToken);
                (uint256 reserve0, uint256 reserve1, ) = IUniswapV2Pair(pair).getReserves();
                (uint256 reserveInput, uint256 reserveOutput) = inToken == token0
                    ? (reserve0, reserve1)
                    : (reserve1, reserve0);
                uint256 amountInput = ERC20(inToken).balanceOf(pair) - reserveInput;
                uint256 amountOutput = UniswapV2Library.getAmountOut(amountInput, reserveInput, reserveOutput, fee);
                (uint256 amount0Out, uint256 amount1Out) = inToken == token0
                    ? (uint256(0), amountOutput)
                    : (amountOutput, uint256(0));

                address nextPair = recipient;
                if (i != size - 1) {
                    (, nextPair, , ) = input.decodePathByIndex(bytesOffset, i + 1);
                }
                IUniswapV2Pair(pair).swap(amount0Out, amount1Out, nextPair, new bytes(0));
            }
        }
    }

    function sweepV2SwapFees(address token, address recipient, uint256 amountMinimum) internal onlyOwner {
        Payments.sweep(token, recipient, amountMinimum);
    }

    function v2SwapExactInput(
        address recipient,
        uint256 amountIn,
        uint256 amountOutMinimum,
        address payer,
        uint256 bytesOffset,
        bytes calldata input
    ) internal {
        (address fromToken, address pair, , ) = input.decodePathByIndex(bytesOffset, 0);
        if (v2_fee_bips > 0) {
            uint256 fee = (amountIn * v2_fee_bips) / FEE_BIPS_BASE;
            Permit2Payments.payOrPermit2Transfer(fromToken, payer, address(this), fee);
            amountIn = amountIn - fee;
        }

        if (amountIn != Constants.ALREADY_PAID) {
            // amountIn of 0 to signal that the pair already has the tokens
            payOrPermit2Transfer(fromToken, payer, pair, amountIn);
        }
        (, , , address _token) = input.decodePathLast(bytesOffset);
        ERC20 tokenOut = ERC20(_token);
        uint256 balanceBefore = tokenOut.balanceOf(recipient);

        _v2Swap(input, bytesOffset, recipient);

        uint256 amountOut = tokenOut.balanceOf(recipient) - balanceBefore;
        if (amountOut < amountOutMinimum) revert V2TooLittleReceived();
    }

    //    function v2SwapExactOutput(
    //        address recipient,
    //        uint256 amountOut,
    //        uint256 amountInMaximum,
    //        address payer,
    //        uint256 bytesOffset,
    //        bytes calldata input
    //    ) internal {
    //        revert('Not implemented');
    //
    //        // (uint256 amountIn, address firstPair) = UniswapV2Library.getAmountInMultihop(amountOut, path);
    //        // if (amountIn > amountInMaximum) revert V2TooMuchRequested();
    //        // payOrPermit2Transfer(path[0], payer, firstPair, amountIn);
    //        // _v2Swap(path, fees, recipient);
    //    }
}
