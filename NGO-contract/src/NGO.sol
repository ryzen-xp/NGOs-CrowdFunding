// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.27;

contract NGO_Funding {
    address payable public immutable admin;

    constructor() {
        admin = payable(msg.sender);
    }

    // Events
    event NGORegistered(address indexed NGO_owner, uint256 index, string uri);
    event DonationMade(address indexed donor, address indexed NGO_owner, uint256 amount);
    event RequestCreated(address indexed NGO_owner, uint256 requestIdx, string uri, uint256 amount);
    event VoteCast(address indexed voter, uint256 requestIdx, bool voteYes, uint256 voteWeight, address NGO);
    event RequestFinalized(uint256 indexed requestIdx, address finalizer_address);
    event BlacklistVote(address indexed voter, address ngo);
    event NGOBlacklisted(address indexed ngo);

    // Custom Errors
    error ZeroAddress();
    error BlacklistedNGO();
    error UnverifiedNGO();
    error AlreadyVoted();
    error VotingPeriodOver();
    error PaymentFailed();
    error InsufficientFunds();
    error Unauthorized();

    // Modifiers
    modifier onlyNgo() {
        if (!registered[msg.sender]) {
            revert UnverifiedNGO();
        }
        _;
    }

    modifier onlyDonor(address _ngo) {
        if (Donations[msg.sender][_ngo] == 0) {
            revert Unauthorized();
        }
        _;
    }

    struct NGO {
        string uri;
        address owner;
        uint256 totalDonor;
        uint256 totalValue;
        bool blacklisted;
        uint256 totalBlockVotes;
        address[] Donors;
    }

    struct Request {
        string uri;
        uint256 amount;
        address recipient;
        bool completed;
        uint256 startTime;
        uint256 yesVotes;
        uint256 noVotes;
        mapping(address => bool) approvals;
    }

    mapping(address => NGO) public NGOs;
    mapping(address => bool) public registered;
    mapping(address => address[]) private DonorsNgo;
    mapping(address => mapping(address => uint256)) public Donations;
    mapping(address => Request[]) public Requests;
    mapping(address => mapping(address => bool)) public blacklistByVoters;

    // Get donor information
    function getDonorInfo() external view returns (address[] memory) {
        return DonorsNgo[msg.sender];
    }

    // Register an NGO
    function register(string calldata _uri) external {
        require(!registered[msg.sender], "NGO already registered");
        NGO storage newNGO = NGOs[msg.sender];
        newNGO.uri = _uri;
        newNGO.owner = msg.sender;
        registered[msg.sender] = true;

        emit NGORegistered(msg.sender, block.timestamp, _uri);
    }

    // Donate to an NGO
    function donate(address _ngo) external payable {
        NGO storage ngo = NGOs[_ngo];
        require(!ngo.blacklisted, "NGO is blacklisted");
        require(msg.value > 0, "Insufficient funds");

        ngo.totalValue += msg.value;

        if (Donations[msg.sender][_ngo] == 0) {
            ngo.totalDonor++;
            ngo.Donors.push(msg.sender);
            DonorsNgo[msg.sender].push(_ngo);
        }

        Donations[msg.sender][_ngo] += msg.value;

        emit DonationMade(msg.sender, _ngo, msg.value);
    }

    // Create a spending request
    function createRequest(string calldata _uri, address _recipient, uint256 _amount) external onlyNgo {
        if (_recipient == address(0)) revert ZeroAddress();
        NGO storage ngo = NGOs[msg.sender];
        if (ngo.totalValue < _amount) revert InsufficientFunds();

        Requests[msg.sender].push();
        Request storage newRequest = Requests[msg.sender][Requests[msg.sender].length - 1];
        newRequest.uri = _uri;
        newRequest.amount = _amount;
        newRequest.recipient = _recipient;
        newRequest.completed = false;
        newRequest.startTime = block.timestamp;

        emit RequestCreated(msg.sender, Requests[msg.sender].length - 1, _uri, _amount);
    }

    // Vote on a request
    function voteOnRequest(address _ngo, uint256 idx, bool vote) external onlyDonor(_ngo) {
        Request storage request = Requests[_ngo][idx];
        if (block.timestamp > request.startTime + 7 days) revert VotingPeriodOver();
        if (request.approvals[msg.sender]) revert AlreadyVoted();

        if (vote) {
            request.yesVotes += Donations[msg.sender][_ngo];
        } else {
            request.noVotes += Donations[msg.sender][_ngo];
        }

        request.approvals[msg.sender] = true;

        emit VoteCast(msg.sender, idx, vote, Donations[msg.sender][_ngo], _ngo);

        uint256 totalVotes = request.yesVotes + request.noVotes;
        if (totalVotes > 0 && request.yesVotes * 2 > totalVotes) {
            finalizeRequestAutomatically(_ngo, idx);
        }
    }

    function finalizeRequestAutomatically(address _ngo, uint256 _requestIdx) internal {
        Request storage request = Requests[_ngo][_requestIdx];
        if (request.completed) return;

        NGO storage ngo = NGOs[_ngo];
        require(ngo.totalValue >= request.amount, "Insufficient funds");

        (bool success,) = request.recipient.call{value: request.amount}("");
        if (!success) revert PaymentFailed();

        ngo.totalValue -= request.amount;
        request.completed = true;

        emit RequestFinalized(_requestIdx, _ngo);
    }

    // Vote to blacklist an NGO
    function voteToBlacklist(address _ngo) external onlyDonor(_ngo) {
        NGO storage ngo = NGOs[_ngo];
        require(!ngo.blacklisted, "NGO already blacklisted");

        ngo.totalBlockVotes++;
        blacklistByVoters[_ngo][msg.sender] = true;

        emit BlacklistVote(msg.sender, _ngo);

        if (ngo.totalBlockVotes * 100 > ngo.totalDonor * 55) {
            blacklistAndReleaseFunds(_ngo);
        }
    }

    function blacklistAndReleaseFunds(address _ngo) internal {
        NGO storage ngo = NGOs[_ngo];
        require(!ngo.blacklisted, "NGO already blacklisted");

        ngo.blacklisted = true;

        uint256 totalValue = ngo.totalValue;
        uint256 adminFee = (totalValue * 2) / 100;
        uint256 remainingFunds = totalValue - adminFee;

        (bool successAdmin,) = admin.call{value: adminFee}("");
        require(successAdmin, "Admin payment failed");

        for (uint256 i = 0; i < ngo.Donors.length; i++) {
            address donor = ngo.Donors[i];
            uint256 donorValue = Donations[donor][_ngo];
            uint256 donorShare = (remainingFunds * donorValue) / totalValue;

            (bool successDonor,) = donor.call{value: donorShare}("");
            if (successDonor) {
                Donations[donor][_ngo] = 0;
            }
        }

        ngo.totalValue = 0;

        emit NGOBlacklisted(_ngo);
    }

    function getRequestCount() external view returns (uint256) {
        return Requests[msg.sender].length;
    }
}
