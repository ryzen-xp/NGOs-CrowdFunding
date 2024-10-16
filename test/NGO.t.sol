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
    string public _uri = "http://ryzen-xp";

    event RequestCreated(address indexed NGO_owner, uint256 indexed requestIdx, string uri, uint256 amount);

    struct Request {
        string uri;
        uint256 amount;
        address recipient;
        bool completed;
        bool approval;
        uint256 yesVotes;
        uint256 noVotes;
        uint256 startTime;
        uint256 endTime;
        bool finalized;
        mapping(address => bool) approvals;
    }

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
        ngo.donate{value: 20 ether}(ngoowner);

        (string memory uri, address owner, uint256 totalDonor, uint256 totalValue, bool isRegistered, bool blacklisted)
        = ngo.NGOs(ngoowner);
        assertEq(uri, "https://example.com/ngo");
        assertEq(owner, ngoowner);
        assertEq(totalDonor, 1);
        assertFalse(blacklisted);

        assertTrue(isRegistered);
        assertEq(totalValue, 20 ether);
        vm.prank(donor1);
        uint256 amount = ngo.get_valByDonor(ngoowner);
        assertEq(amount, 20 ether);
    }

    function test_createrequest() external {
        vm.prank(ngoowner);
        ngo.register("http://admin/com");

        vm.prank(donor1);
        vm.deal(donor1, 100 ether);
        ngo.donate{value: 20 ether}(ngoowner);

        // Expect the request creation event
        vm.prank(ngoowner);
        vm.expectEmit(true, true, true, true); // Expect specific indexed values to match
        emit RequestCreated(ngoowner, 0, _uri, 2 ether);

        // Create the request
        ngo.createRequest(_uri, ngoowner, 2 ether);

        // Check if the request was created correctly
        (
            string memory uri,
            uint256 amount,
            address recipient,
            bool completed,
            bool approval,
            uint256 yesVotes,
            uint256 noVotes,
            uint256 startTime,
            uint256 endTime,
            bool finalized
        ) = ngo.Requests(ngoowner, 0);

        assertEq(uri, _uri);
        assertEq(amount, 2 ether);
        assertEq(recipient, ngoowner);
        assertFalse(completed);
        assertFalse(approval);
        assertEq(yesVotes, 0);
        assertEq(noVotes, 0);
        assertEq(startTime, block.timestamp);
        assertEq(endTime, block.timestamp + ngo.duration());
        assertFalse(finalized);
    }

    function test_voteOnrequest() external {
        vm.prank(ngoowner);
        ngo.register("http://admin/com");

        vm.prank(donor1);
        vm.deal(donor1, 100 ether);
        ngo.donate{value: 20 ether}(ngoowner);

        // Expect the request creation event
        vm.prank(ngoowner);
        vm.expectEmit(true, true, true, true);
        emit RequestCreated(ngoowner, 0, _uri, 2 ether);

        ngo.createRequest(_uri, ngoowner, 2 ether);

        // Prank as donor and cast vote
        vm.prank(donor1);
        ngo.voteOnRequest(ngoowner, 0, true);

        (
            string memory uri,
            uint256 amount,
            address recipient,
            bool completed,
            bool approval,
            uint256 yesVotes,
            uint256 noVotes,
            uint256 startTime,
            uint256 endTime,
            bool finalized
        ) = ngo.Requests(ngoowner, 0);

        // Ensure the request is updated correctly after voting
        assertEq(uri, _uri);
        assertEq(amount, 2 ether);
        assertEq(recipient, ngoowner);
        assertFalse(completed);
        assertFalse(approval);
        assertEq(yesVotes, 20 ether);
        assertEq(noVotes, 0);
        assertEq(startTime, block.timestamp);
        assertEq(endTime, block.timestamp + ngo.duration());
        assertFalse(finalized);
    }

    function test_finalizeRequest() external {
        vm.prank(ngoowner);
        ngo.register("http://admin/com");

        vm.prank(donor1);
        vm.deal(donor1, 100 ether);
        ngo.donate{value: 20 ether}(ngoowner);

        // Expect the request creation event
        vm.prank(ngoowner);
        vm.expectEmit(true, true, true, true);
        emit RequestCreated(ngoowner, 0, _uri, 2 ether);

        ngo.createRequest(_uri, ngoowner, 2 ether);

        // Prank as donor and cast vote
        vm.prank(donor1);
        ngo.voteOnRequest(ngoowner, 0, true);

        vm.prank(ngoowner);
        vm.warp(block.timestamp + time);
        ngo.finalizeRequest(0);

        (
            string memory uri,
            uint256 amount,
            address recipient,
            bool completed,
            bool approval,
            uint256 yesVotes,
            uint256 noVotes,
            ,
            ,
            bool finalized
        ) = ngo.Requests(ngoowner, 0);
        assertEq(uri, _uri);
        assertEq(amount, 2 ether);
        assertEq(recipient, ngoowner);
        assertTrue(completed);
        assertTrue(approval);
        assertEq(yesVotes, 20 ether);
        assertEq(noVotes, 0);
        // assertEq(startTime, block.timestamp);
        // assertEq(endTime, block.timestamp );
        assertTrue(finalized);
    }
}
