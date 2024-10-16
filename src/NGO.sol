// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.27;

contract NGO_Funding {
    address public admin;
    uint256 public duration;

    constructor(uint256 duration_sec) {
        admin = msg.sender;
        duration = duration_sec; // _count should be in seconds
    }

    event NGORegistered(address indexed NGO_owner, uint256 index, string uri);
    event DonationMade(address indexed donor, address indexed NGO_owner, uint256 amount);
    event RequestCreated(address indexed NGO_owner, uint256 indexed requestIdx, string uri, uint256 amount);
    event VoteCast(address indexed voter, uint256 indexed requestIdx, bool voteYes, uint256 voteWeight);
    event RequestFinalized(uint256 indexed requestIdx, bool approved);

    modifier onlyNgo() {
        require(NGOs[msg.sender].isRegistered, "Only NGO owner can call this function");
        _;
    }

    modifier onlyDonor(address _ngo) {
        require(Donations[msg.sender][_ngo] != 0, "Not a donor");
        _;
    }

    struct NGO {
        string uri;
        address owner;
        uint256 totalDonor;
        uint256 totalValue;
        bool isRegistered;
        bool blacklisted;
        address[] donors;
    }

    struct donor {
        address[] ngos;
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
    mapping(address => donor) private Donors; // Keep private, but simulate public access with getters
    mapping(address => mapping(address => uint256)) public Donations;
    mapping(address => Request[]) public Requests;

    // Custom getter for Donors mapping
    function getDonorInfo() external view returns (address[] memory) {
        return Donors[msg.sender].ngos;
    }

    function register(string calldata _uri) external {
        require(!NGOs[msg.sender].isRegistered, "NGO already registered");

        NGO storage newNGO = NGOs[msg.sender];
        newNGO.uri = _uri;
        newNGO.owner = msg.sender;
        newNGO.isRegistered = true;

        emit NGORegistered(msg.sender, block.timestamp, _uri);
    }

    function donate(address _ngo) external payable {
        require(NGOs[_ngo].isRegistered, "NGO is not registered");
        require(!NGOs[_ngo].blacklisted, "NGO is blacklisted");
        require(msg.value > 0, "Invalid value");

        NGO storage ngx = NGOs[_ngo];
        ngx.totalValue += msg.value;

        if (Donations[msg.sender][_ngo] == 0) {
            Donations[msg.sender][_ngo] = msg.value;
            ngx.totalDonor++;
            ngx.donors.push(msg.sender);
        } else {
            Donations[msg.sender][_ngo] += msg.value;
        }

        Donors[msg.sender].ngos.push(_ngo);

        emit DonationMade(msg.sender, _ngo, msg.value);
    }

    function createRequest(string memory _uri, address _recipient, uint256 _amount) external onlyNgo {
        require(_recipient != address(0), "Recipient is zero address");
        require(NGOs[msg.sender].totalValue >= _amount, "Insufficient funds for this request");

        Request storage newRequest = Requests[msg.sender].push();
        newRequest.uri = _uri;
        newRequest.amount = _amount;
        newRequest.recipient = _recipient;
        newRequest.completed = false;
        newRequest.approval = false;
        newRequest.startTime = block.timestamp;
        newRequest.endTime = block.timestamp + duration;
        newRequest.finalized = false;

        emit RequestCreated(msg.sender, Requests[msg.sender].length - 1, _uri, _amount);
    }

    function voteOnRequest(address _ngo, uint256 idx, bool voteYes) external onlyDonor(_ngo) {
        require(!NGOs[_ngo].blacklisted, "NGO is blacklisted");

        Request storage request = Requests[_ngo][idx];
        require(block.timestamp <= request.endTime, "Voting is closed.");
        require(!request.approvals[msg.sender], "You have already voted.");

        uint256 voteWeight = Donations[msg.sender][_ngo];
        if (voteYes) {
            request.yesVotes += voteWeight;
        } else {
            request.noVotes += voteWeight;
        }

        request.approvals[msg.sender] = true;

        emit VoteCast(msg.sender, idx, voteYes, voteWeight);
    }

    function finalizeRequest(uint256 _requestIdx) external onlyNgo {
        Request storage request = Requests[msg.sender][_requestIdx];
        require(!request.finalized, "Request already finalized.");
        require(block.timestamp >= request.endTime, "Voting period is not over.");

        NGO storage ngo = NGOs[msg.sender];
        uint256 totalVotes = request.yesVotes + request.noVotes;
        require(totalVotes > 0, "No votes were cast.");

        if (request.yesVotes * 2 > totalVotes) {
            require(ngo.totalValue >= request.amount, "Not enough funds.");
            (bool success,) = payable(request.recipient).call{value: request.amount}("");
            require(success, "Transaction failed");
            ngo.totalValue -= request.amount;
            request.completed = true;
            request.approval = true;
        }

        request.finalized = true;
        emit RequestFinalized(_requestIdx, request.approval);
    }

    function get_valByDonor(address _ngo) external view returns (uint256) {
        require(address(_ngo) != address(0), "Zero add");
        return Donations[msg.sender][_ngo];
    }

    function get_valByNGO(address _donor) external view returns (uint256) {
        require(address(_donor) != address(0), "Zero add");
        return Donations[msg.sender][_donor];
    }
}
