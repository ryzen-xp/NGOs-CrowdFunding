// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.27;


contract NGO_Funding  {
    address public admin;
    uint256 public duration;
    uint256 public fundReleaseTime = 7 days ;

    constructor(uint256 duration_sec ) {
        admin = msg.sender;
        duration = duration_sec;
    }

    enum Status {
        Unverified,
        Verified,
        Blocked
    }

    


    // Events
    event NGORegistered(address indexed NGO_owner, uint256 index, string uri);
    event DonationMade(address indexed donor, address indexed NGO_owner, uint256 amount);
    event RequestCreated(address indexed NGO_owner, uint256 requestIdx, string uri, uint256 amount);
    event VoteCast(address indexed voter, uint256 requestIdx, bool voteYes, uint256 voteWeight , address Ngo);
    event RequestFinalized(uint256 indexed requestIdx, address finalizer_address);
    event authorized_NGO(address );
    event whilteList(address _ngo);

    // Custom Errors for Gas Optimization
    error ZeroAddress();
    error BlacklistedNGO();
    error UnverifiedNGO();
    error NotBlacklistedNGO();
    error AlreadyVoted();
    error InsufficientVotes();
    error VotingPeriodOver();
    error PaymentFailed();
    error InsufficientFunds();
    error Unauthorized();
    error AdminOnly();
    error NotRegisteredNGO();

    // Modifiers
    modifier onlyNgo() {
        if (NGOs[msg.sender].status!= Status.Verified) {
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
        Status status;
       
        address[] Donors;
    }

    struct Request {
        string uri;
        uint256 amount;
        address recipient;
        bool completed;
        uint startTime ;       
        uint256 yesVotes;
        uint256 noVotes;
        mapping(address => bool) approvals;
       
       
    }

    mapping(address => uint256) public BlacklistTimestamp;

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
             require(newNGO.status != Status.Verified , "NGO already registered");
        require(newNGO.status != Status.Blocked , "NGO Blocked");


        newNGO.uri = _uri;
        newNGO.owner = msg.sender;
        newNGO.status= Status.Unverified;

        emit NGORegistered(msg.sender, block.timestamp, _uri);
    }

    function Authorized_NGO(address _ngo)external {
         NGO storage newNGO = NGOs[_ngo];
        require(newNGO.status != Status.Unverified , "NGO already verified or blocked");
        
        newNGO.status =Status.Verified ;
        emit authorized_NGO(_ngo );
    }

    // Donate to an NGO
 function donate(address _ngo) external payable  {
    NGO storage ngo = NGOs[_ngo];
    require(ngo.status == Status.Verified, "NGO is Blocked or Unverified");
    require(msg.value > 0, "Insufficient funds");

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
    if (_recipient == address(0)) revert ZeroAddress();
    NGO storage ngo = NGOs[msg.sender];
   
    if (ngo.totalValue < _amount) revert InsufficientFunds();

    // Initialize the new request and add it to the NGO's requests array
    Requests[msg.sender].push();
    Request storage newRequest = Requests[msg.sender][Requests[msg.sender].length - 1];
    newRequest.uri = _uri;
    newRequest.amount = _amount;
    newRequest.recipient = _recipient;
    newRequest.completed = false;
    newRequest.startTime = block.timestamp;
    newRequest.yesVotes = 0;
    newRequest.noVotes = 0;

    emit RequestCreated(msg.sender, Requests[msg.sender].length - 1, _uri, _amount);
}


    // Vote on a request
    function voteOnRequest(address _ngo, uint256 idx, bool voteYes) external onlyDonor(_ngo) {
        NGO storage ngo = NGOs[_ngo];
        if (ngo.status == Status.Blocked ) revert BlacklistedNGO();

        Request storage request = Requests[_ngo][idx];
        if (block.timestamp > request.startTime + duration) revert VotingPeriodOver();
        if (request.approvals[msg.sender]) revert AlreadyVoted();

        uint256 voteWeight = Donations[msg.sender][_ngo];
        if (voteYes) {
            request.yesVotes += voteWeight;
        } else {
            request.noVotes += voteWeight;
        }

        request.approvals[msg.sender] = true;

        emit VoteCast(msg.sender, idx, voteYes, voteWeight , _ngo);
    }

    // Finalize a request
    function finalizeRequest(uint256 _requestIdx) external onlyNgo  {
        Request storage request = Requests[msg.sender][_requestIdx];
        require(!request.completed , "Request proccessed");
        require(block.timestamp > request.startTime + duration , "Voting Not Finish"  ); 
         

        NGO storage ngo = NGOs[msg.sender];
        uint256 totalVotes = request.yesVotes + request.noVotes;
        if (totalVotes == 0) revert InsufficientVotes();

        if (request.yesVotes * 2 > totalVotes) {
            if (ngo.totalValue < request.amount) revert InsufficientFunds();
            (bool success,) = request.recipient.call{value: request.amount}("");
            if (!success) revert PaymentFailed();
            ngo.totalValue -= request.amount;
            
            
        }

       request.completed = true;
        emit RequestFinalized(_requestIdx, msg.sender );
    }


    // Blacklist an NGO
    function Blacklist(address _ngo) external onlyAdmin {
        if (_ngo == address(0)) revert ZeroAddress();

        NGO storage ngo = NGOs[_ngo];
        if (ngo.status != Status.Verified) revert NotRegisteredNGO();
        if (ngo.status == Status.Blocked) revert BlacklistedNGO();

        ngo.status = Status.Blocked;
        BlacklistTimestamp[_ngo]= block.timestamp;
    }

    function WhilteList(address _ngo ) external  onlyAdmin() {
        if(_ngo == address(0) ){
             revert ZeroAddress();
        }
        NGO storage ngo = NGOs[_ngo];
        if(ngo.status == Status.Blocked){
            ngo.status = Status.Unverified ;
            BlacklistTimestamp[_ngo]= 0;
        }
        else{
            revert NotBlacklistedNGO();
        }
        emit whilteList(_ngo );
    }

    // Release funds to donors in case of blacklisting
    function ReleaseFund_Donor(address _ngo) external onlyAdmin  {
        if (_ngo == address(0)) revert ZeroAddress();
        require(BlacklistTimestamp[_ngo] > 0 );
        require(BlacklistTimestamp[_ngo] + fundReleaseTime < block.timestamp , "Fund release time not reached");

        NGO storage ngo = NGOs[_ngo];
        
        if (ngo.status != Status.Blocked) revert NotBlacklistedNGO();

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
