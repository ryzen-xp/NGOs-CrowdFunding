// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.27;

contract NGO_Funding {
    address public admin;
    uint256 public idx;

    // Constructor sets the admin
    constructor(uint256 _count) {
        admin = msg.sender;
        idx = _count;
    }

    // Modifier to allow only the NGO owner to call certain functions
    modifier onlyNgo(uint256 _idx) {
        require(NGOs[_idx].owner == msg.sender, "Only the NGO owner can call this function");
        _;
    }

    modifier onlyDonor(uint256 _idx) {
        require(Donations[msg.sender][_idx] > 0, "Not donor");
        _;
    }

    // Struct to define NGO properties
    struct NGO {
        string uri;
        address owner;
        uint256 totalDonor;
        address[] donors;
        uint256[] donation;
        uint256 totalValue;
        bool isRegistered;
        bool blacklisted;
    }

    // Struct for Request properties with added voting features
    struct Request {
        string uri;
        uint256 amount;
        address recipient;
        bool completed;
        bool approval;
        uint256 yesVotes; // Total weight of yes votes
        uint256 noVotes; // Total weight of no votes
        uint256 startTime; // Voting start time
        uint256 endTime; // Voting end time (2 days)
        mapping(address => bool) approvals; // Donor addresses who voted
        bool finalized;
    }

    mapping(uint256 => NGO) public NGOs;

    // Mapping of donor donations
    mapping(address => mapping(uint256 => uint256)) public Donations;

    Request[] public requests;

    // Function to register an NGO
    function register(string calldata _uri) external returns (uint256 _idx) {
        ++idx;
        NGO storage newNGO = NGOs[idx];
        require(!newNGO.isRegistered, "NGO already registered");

        newNGO.uri = _uri;
        newNGO.owner = msg.sender;
        newNGO.totalDonor = 0;
        newNGO.totalValue = 0;
        newNGO.isRegistered = true;
        newNGO.blacklisted = false;
        return _idx;
    }

    // Function to donate to an NGO
    function donate(uint256 _idx) external payable {
        require(NGOs[_idx].isRegistered, "NGO is not registered");
        require(!NGOs[_idx].blacklisted, "NGO is blacklisted");
        require(msg.value > 0, "Invalid value");

        NGO storage ngo = NGOs[_idx];
        ngo.totalValue += msg.value;
        ngo.totalDonor++;
        ngo.donors.push(msg.sender);
        ngo.donation.push(msg.value);
        Donations[msg.sender][_idx] += msg.value;
    }

    // Function to create a request for funds by the NGO owner
    function createRequest(uint256 _idx, string memory _uri, address _recipient, uint256 _amount)
        external
        onlyNgo(_idx)
    {
        require(NGOs[_idx].totalValue >= _amount, "Insufficient funds for this request");

        Request storage newRequest = requests.push();
        newRequest.uri = _uri;
        newRequest.amount = _amount;
        newRequest.recipient = _recipient;
        newRequest.completed = false;
        newRequest.approval = false;
        newRequest.yesVotes = 0;
        newRequest.noVotes = 0;
        newRequest.startTime = block.timestamp;
        newRequest.endTime = block.timestamp + 2 days; // Voting lasts for 2 days
        newRequest.finalized = false;
    }

    // Function to vote on a request by donors, with weight based on donations
    function voteOnRequest(uint256 _idx, bool voteYes) external onlyDonor(_idx) {
        Request storage request = requests[_idx];
        require(block.timestamp <= request.endTime, "Voting is closed.");
        require(!request.approvals[msg.sender], "You have already voted.");

        // Calculate vote weight based on the donor's donation
        uint256 voteWeight = Donations[msg.sender][_idx];

        // Register the vote
        if (voteYes) {
            request.yesVotes += voteWeight;
        } else {
            request.noVotes += voteWeight;
        }

        // Mark the donor as having voted
        request.approvals[msg.sender] = true;
    }

    // Function to finalize a request based on the voting result
    function finalizeRequest(uint256 _requestIdx, uint256 _ngoIdx) external {
        Request storage request = requests[_requestIdx];
        NGO storage ngo = NGOs[_ngoIdx];

        require(block.timestamp > request.endTime, "Voting period is not over.");
        require(!request.finalized, "Request already finalized.");

        uint256 totalVotes = request.yesVotes + request.noVotes;
        require(totalVotes > 0, "No votes were cast.");

        // Check if more than 50% of the vote weight is 'yes'
        if (request.yesVotes * 2 > totalVotes) {
            // Approve the request and transfer funds
            require(ngo.totalValue >= request.amount, "Not enough funds.");
            payable(request.recipient).transfer(request.amount);
            request.completed = true;
            request.approval = true;
            ngo.totalValue -= request.amount;
        } else {
            // Reject the request
            request.completed = false;
            request.approval = false;
        }

        // Mark the request as finalized
        request.finalized = true;
    }

    // Function to get the number of requests
    function getRequestCount() public view returns (uint256) {
        return requests.length;
    }
}
