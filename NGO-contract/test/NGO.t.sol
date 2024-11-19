// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.27;

import "forge-std/Test.sol";
import "../src/NGO.sol";

contract NGO_FundingTest is Test {
    NGO_Funding public ngoFunding;
    address public admin = address(this); // Test admin address
    address public ngo1 = address(0x1); // Test NGO address
    address public ngo2 = address(0x2); // Test NGO address
    address public donor1 = address(0x3); // Test donor address
    address public donor2 = address(0x4); // Test donor address

    function setUp() public {
        // Deploy the contract
        ngoFunding = new NGO_Funding();
        // Label addresses for easier debugging
        vm.label(admin, "Admin");
        vm.label(ngo1, "NGO 1");
        vm.label(ngo2, "NGO 2");
        vm.label(donor1, "Donor 1");
        vm.label(donor2, "Donor 2");
    }

    function testRegisterNGO() public {
        // Register NGO1
        vm.startPrank(ngo1);
        ngoFunding.register("NGO1_URI");
        vm.stopPrank();

        // Assert that the NGO is registered
        (string memory uri, address owner,,,,) = ngoFunding.NGOs(ngo1);
        assertEq(uri, "NGO1_URI");
        assertEq(owner, ngo1);
        assertTrue(ngoFunding.registered(ngo1));
    }

    function testDonate() public {
        // Register NGO1
        vm.startPrank(ngo1);
        ngoFunding.register("NGO1_URI");
        vm.stopPrank();

        // Donate to NGO1
        vm.deal(donor1, 10 ether); // Fund donor1
        vm.startPrank(donor1);
        ngoFunding.donate{value: 5 ether}(ngo1);
        vm.stopPrank();

        // Assert donation
        (,, uint256 totalDonor, uint256 totalValue,,) = ngoFunding.NGOs(ngo1);
        assertEq(totalDonor, 1);
        assertEq(totalValue, 5 ether);
        assertEq(ngoFunding.Donations(donor1, ngo1), 5 ether);
    }

    function testCreateRequest() public {
        // Register NGO1
        vm.startPrank(ngo1);
        ngoFunding.register("NGO1_URI");
        vm.stopPrank();

        // Donate to NGO1
        vm.deal(donor1, 10 ether);
        vm.startPrank(donor1);
        ngoFunding.donate{value: 5 ether}(ngo1);
        vm.stopPrank();

        // Create a request
        vm.startPrank(ngo1);
        ngoFunding.createRequest("Request_URI", donor1, 2 ether);
        vm.stopPrank();

        // Assert request details
        (string memory uri, uint256 amount, address recipient, bool completed,,,) = ngoFunding.Requests(ngo1, 0);
        assertEq(uri, "Request_URI");
        assertEq(amount, 2 ether);
        assertEq(recipient, donor1);
        assertFalse(completed);
    }

    function testVoteOnRequest() public {
        // Register NGO1
        vm.startPrank(ngo1);
        ngoFunding.register("NGO1_URI");
        vm.stopPrank();

        // Donate to NGO1
        vm.deal(donor1, 10 ether);
        vm.startPrank(donor1);
        ngoFunding.donate{value: 5 ether}(ngo1);
        vm.stopPrank();

        // Create a request
        vm.startPrank(ngo1);
        ngoFunding.createRequest("Request_URI", donor1, 2 ether);
        vm.stopPrank();

        // Vote on the request
        vm.startPrank(donor1);
        ngoFunding.voteOnRequest(ngo1, 0, true);
        vm.stopPrank();

        // Assert vote results
        (,,,,, uint256 yesVotes, uint256 noVotes) = ngoFunding.Requests(ngo1, 0);
        assertEq(yesVotes, 5 ether);
        assertEq(noVotes, 0);
    }

    function testBlacklistNGO() public {
        // Register NGO1
        vm.startPrank(ngo1);
        ngoFunding.register("NGO1_URI");
        vm.stopPrank();

        // Donate to NGO1
        vm.deal(donor1, 10 ether);
        vm.startPrank(donor1);
        ngoFunding.donate{value: 5 ether}(ngo1);
        vm.stopPrank();

        // Vote to blacklist NGO1
        vm.startPrank(donor1);
        ngoFunding.voteToBlacklist(ngo1);
        vm.stopPrank();

        // Assert blacklist status
        (,,,, bool blacklisted,) = ngoFunding.NGOs(ngo1);
        assertTrue(blacklisted);
    }

    function testReleaseFundsOnBlacklist() public {
        // Register NGO1
        vm.startPrank(ngo1);
        ngoFunding.register("NGO1_URI");
        vm.stopPrank();

        // Donate to NGO1
        vm.deal(donor1, 10 ether);
        vm.deal(donor2, 10 ether);
        vm.startPrank(donor1);
        ngoFunding.donate{value: 5 ether}(ngo1);
        vm.stopPrank();

        vm.startPrank(donor2);
        ngoFunding.donate{value: 5 ether}(ngo1);
        vm.stopPrank();

        // Vote to blacklist NGO1
        vm.startPrank(donor1);
        ngoFunding.voteToBlacklist(ngo1);
        vm.stopPrank();

        vm.startPrank(donor2);
        ngoFunding.voteToBlacklist(ngo1);
        vm.stopPrank();

        // Assert refunds to donors
        assertEq(donor1.balance, 10 ether);
        assertEq(donor2.balance, 10 ether);
    }
}
