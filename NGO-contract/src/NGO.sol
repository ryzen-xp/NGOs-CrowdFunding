// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.27;

import "../lib/openzeppelin-contracts/contracts/utils/ReentrancyGuard.sol";

contract NGO_Funding is ReentrancyGuard {
    address public admin;
    uint256 public duration;

    constructor(uint256 duration_sec) {
        admin = msg.sender;
        duration = duration_sec;
    }

    enum status {
        Unverified,
        Verified,
        Blocked
    }

    // Events
    event NGORegistered(address indexed NGO_owner, uint256 index, string uri);
    event DonationMade(address indexed donor, address indexed NGO_owner, uint256 amount);
    event RequestCreated(address indexed NGO_owner, uint256 requestIdx, string uri, uint256 amount);
    event VoteCast(address indexed voter, uint256 requestIdx, bool voteYes, uint256 voteWeight);
    event RequestFinalized(uint256 indexed requestIdx, bool approved);

    // Custom Errors for Gas Optimization
    error ZeroAddress();
    error BlacklistedNGO();
    error NotRegisteredNGO();
    error NotBlacklistedNGO();
    error AlreadyVoted();
    error InsufficientVotes();
    error VotingPeriodNotOver();
    error PaymentFailed();
    error InsufficientFunds();
    error Unauthorized();
    error AdminOnly();

    // Modifiers
    modifier onlyNgo() {
        if (!NGOs[msg.sender].isRegistered) {
            revert NotRegisteredNGO();
        }
        _;
    }

    modifier onlyDonor(address _ngo) {
        if (Donations[msg.sender][_ngo] == 0) {
            revert Unauthorized();
        }
        _;
    }

    modifier onlyAdmin() {
        if (msg.sender != admin) {
            revert AdminOnly();
        }
        _;
    }

    struct NGO {
        string uri;
        address owner;
        uint256 totalDonor;
        uint256 totalValue;
        bool isRegistered;
        bool blacklisted;
        address[] Donors;
    }

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

    mapping(address => NGO) public NGOs;
    mapping(address => address[]) private Donors_ngo;
    mapping(address => mapping(address => uint256)) public Donations;
    mapping(address => Request[]) public Requests;
    // mapping(address => address[]) private Ngo_donor;

    // Function to get the donor info
    function getDonorInfo() external view returns (address[] memory) {
        return Donors_ngo[msg.sender];
    }

    // Register an NGO
    function register(string calldata _uri) external {
        NGO storage newNGO = NGOs[msg.sender];
        require(!newNGO.isRegistered, "NGO already registered");

        newNGO.uri = _uri;
        newNGO.owner = msg.sender;
        newNGO.isRegistered = true;

        emit NGORegistered(msg.sender, block.timestamp, _uri);
    }

    // Donate to an NGO
    function donate(address _ngo) external payable nonReentrant {
        NGO storage ngo = NGOs[_ngo];
        if (!ngo.isRegistered) revert NotRegisteredNGO();
        if (ngo.blacklisted) revert BlacklistedNGO();
        if (msg.value == 0) revert InsufficientFunds();

        ngo.totalValue += msg.value;

        if (Donations[msg.sender][_ngo] == 0) {
            ngo.totalDonor++;
            ngo.Donors.push(msg.sender);
            Donors_ngo[msg.sender].push(_ngo);
        }
        Donations[msg.sender][_ngo] += msg.value;

        emit DonationMade(msg.sender, _ngo, msg.value);
    }

    // Create a funding request
    function createRequest(string calldata _uri, address _recipient, uint256 _amount) external onlyNgo {
        NGO memory ngo = NGOs[msg.sender];
        if (_recipient == address(0)) revert ZeroAddress();
        if (ngo.totalValue < _amount) revert InsufficientFunds();

        Request storage newRequest = Requests[msg.sender].push();
        newRequest.uri = _uri;
        newRequest.amount = _amount;
        newRequest.recipient = _recipient;
        newRequest.startTime = block.timestamp;
        newRequest.endTime = block.timestamp + duration;

        // Requests[msg.sender].push(newRequest);

        emit RequestCreated(msg.sender, Requests[msg.sender].length - 1, _uri, _amount);
    }

    // Vote on a request
    function voteOnRequest(address _ngo, uint256 idx, bool voteYes) external onlyDonor(_ngo) {
        NGO storage ngo = NGOs[_ngo];
        if (ngo.blacklisted) revert BlacklistedNGO();

        Request storage request = Requests[_ngo][idx];
        if (block.timestamp > request.endTime) revert VotingPeriodNotOver();
        if (request.approvals[msg.sender]) revert AlreadyVoted();

        uint256 voteWeight = Donations[msg.sender][_ngo];
        if (voteYes) {
            request.yesVotes += voteWeight;
        } else {
            request.noVotes += voteWeight;
        }

        request.approvals[msg.sender] = true;

        emit VoteCast(msg.sender, idx, voteYes, voteWeight);
    }

    // Finalize a request
    function finalizeRequest(uint256 _requestIdx) external onlyNgo nonReentrant {
        Request storage request = Requests[msg.sender][_requestIdx];
        if (request.finalized) revert VotingPeriodNotOver();
        if (block.timestamp < request.endTime) revert VotingPeriodNotOver();

        NGO storage ngo = NGOs[msg.sender];
        uint256 totalVotes = request.yesVotes + request.noVotes;
        if (totalVotes == 0) revert InsufficientVotes();

        if (request.yesVotes * 2 > totalVotes) {
            if (ngo.totalValue < request.amount) revert InsufficientFunds();
            (bool success,) = request.recipient.call{value: request.amount}("");
            if (!success) revert PaymentFailed();
            ngo.totalValue -= request.amount;
            request.completed = true;
            request.approval = true;
        }

        request.finalized = true;
        emit RequestFinalized(_requestIdx, request.approval);
    }

    // Blacklist an NGO
    function Blacklist(address _ngo) external onlyAdmin {
        if (_ngo == address(0)) revert ZeroAddress();

        NGO storage ngo = NGOs[_ngo];
        if (!ngo.isRegistered) revert NotRegisteredNGO();
        if (ngo.blacklisted) revert BlacklistedNGO();

        ngo.blacklisted = true;
    }

    // Release funds to donors in case of blacklisting
    function ReleaseFund_Donor(address _ngo) external onlyAdmin nonReentrant {
        if (_ngo == address(0)) revert ZeroAddress();

        NGO storage ngo = NGOs[_ngo];
        if (!ngo.isRegistered) revert NotRegisteredNGO();
        if (!ngo.blacklisted) revert NotBlacklistedNGO();

        uint256 totalValue = ngo.totalValue;
        if (totalValue == 0) revert InsufficientFunds();

        uint256 adminFee = (totalValue * 2) / 100;
        uint256 remainingFunds = totalValue - adminFee;

        (bool successAdmin,) = admin.call{value: adminFee}("");
        if (!successAdmin) revert PaymentFailed();

        for (uint256 i = 0; i < ngo.Donors.length; i++) {
            address donor = ngo.Donors[i];
            uint256 donorValue = Donations[donor][_ngo];
            uint256 donorShare = (remainingFunds * donorValue) / totalValue;

            (bool successDonor,) = donor.call{value: donorShare}("");
            if (!successDonor) revert PaymentFailed();

            Donations[donor][_ngo] = 0; // Reset donor donation
        }

        ngo.totalValue = 0; // Reset NGO value
    }

    function getRequestCount() external view returns (uint256) {
        return Requests[msg.sender].length;
    }
}
