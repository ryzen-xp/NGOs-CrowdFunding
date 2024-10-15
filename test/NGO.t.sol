// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.27;

import {Test, console} from "forge-std/Test.sol";
import {NGO_Funding} from "../src/NGO.sol";

contract NGOtest is Test {
    NGO_Funding public ngo;
    uint256 public time = 1_000;
    address public admin = address(1);
    address public ngoowner = address(2);
    address public donor1 = address(3);

    function setUp() public {
        ngo = new NGO_Funding(time);
    }

    function test_register() external {
        vm.prank(ngoowner); // Prank as ngoowner to register the NGO
        ngo.register("http://admin/com");

        // Access the NGO struct for ngoowner and unpack the relevant fields
        (string memory uri, address owner, uint256 totalDonor, uint256 totalValue, bool isRegistered, bool blacklisted)
        = ngo.NGOs(ngoowner);

        // Check if the values match
        assertEq(uri, "http://admin/com");
        assertEq(owner, ngoowner);
        assertTrue(isRegistered);
        assertEq(totalDonor, 0);
        assertEq(totalValue, 0);
        assertEq(blacklisted, false);
    }

    function test_donate() external {
       vm.prank(ngoowner);
        ngo.register("https://example.com/ngo");
      vm.prank(donor1);
      vm.deal(donor1, 100 ether);
      ngo.donate{value : 20 ether}(ngoowner);

       (string memory uri, address owner, uint256 totalDonor, uint256 totalValue, bool isRegistered, bool blacklisted)
        = ngo.NGOs(ngoowner);
        assertEq(uri,"https://example.com/ngo" );
        assertEq(owner , ngoowner);
        assertEq(totalDonor , 1);
          assertEq(blacklisted, false);

        assertTrue(isRegistered);
        assertEq(totalValue , 20 ether );
       uint amout =  ngo.Donations[donor1][ngoowner];
        
      assertEq( amout , 20 ether);

    }
}
