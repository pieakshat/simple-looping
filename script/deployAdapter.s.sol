// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;


import "forge-std/Script.sol";
import {LendleAdapter} from "../src/interfaces/lendleAdapter.sol";

contract DeployAdapter is Script {
    function run() external {
        vm.startBroadcast();

        address pool = 0xCFa5aE7c2CE8Fadc6426C1ff872cA45378Fb7cF3; 
        address oracle = 0x870c9692Ab04944C86ec6FEeF63F261226506EfC; 

        // deploy adapter 
        LendleAdapter adapter = new LendleAdapter(pool, oracle);
        console.log("LendleAdapter deployed at:", address(adapter));
        vm.stopBroadcast();
    }
}