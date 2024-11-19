// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.27;

import "forge-std/Script.sol";
import "../src/NGO.sol";  // Update this path if necessary to match your directory structure

contract DeployNGOFunding is Script {
    function run() external {
        uint private_key = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(private_key);

        // Deploy the contract
        NGO_Funding ngoFunding = new NGO_Funding();

        console.log("NGO_Funding deployed at:", address(ngoFunding));

        vm.stopBroadcast();
    }
}
