// SPDX-License-Identifier: MIT

pragma solidity ^0.8.13;

import {Script} from "forge-std/Script.sol";

import {TokenPool} from "@ccip/contracts/ccip/pools/TokenPool.sol";
import {RateLimiter} from "@ccip/contracts/ccip/libraries/RateLimiter.sol";
import {Client} from "@ccip/contracts/ccip/libraries/Client.sol"; 

contract ConfigurePoolScript is Script {
    function run(
        address localPool, 
        uint64 remoteChainSelector, 
        address remotePool, 
        address remoteToken, 
        bool outboundRateLimiterIsEnabled, 
        uint128 outboundRateLimiterCapacity, 
        uint128 outboundRateLimiterRate,
        bool inboundRateLimiterIsEnabled,
        uint128 inboundRateLimiterCapacity,
        uint128 inboundRateLimiterRate
    ) public {
        vm.startBroadcast();
        bytes[] memory remotePoolAddresses = new bytes[](1);
        remotePoolAddresses[0] = abi.encode(remotePool);
        TokenPool.ChainUpdate[] memory chainToAdd = new TokenPool.ChainUpdate[](1);
        chainToAdd[0] = TokenPool.ChainUpdate({
            remoteChainSelector: remoteChainSelector,
            allowed: true,
            remotePoolAddress: remotePoolAddresses[0],
            remoteTokenAddress: abi.encode(remoteToken),
            outboundRateLimiterConfig: RateLimiter.Config({
                isEnabled: outboundRateLimiterIsEnabled,
                capacity: outboundRateLimiterCapacity,
                rate: outboundRateLimiterRate
            }),
            inboundRateLimiterConfig: RateLimiter.Config({
                isEnabled: inboundRateLimiterIsEnabled,
                capacity: inboundRateLimiterCapacity,
                rate: inboundRateLimiterRate
            })
        });
        TokenPool(localPool).applyChainUpdates(chainToAdd);
        vm.stopBroadcast();
    }
}