// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.27;

contract NGO_Funding {
  
    address public admin;
    uint256 public  idx;

    // Struct to define NGO properties
    struct NGO {
        string uri; 
        address owner;    
        uint  totalDonor ;       
             
        uint256 totalValue;    
        bool isRegistered;        
        bool blacklisted;      
       
    }
    struct Donor{
        
        uint totalDonation;
        

    }

   
    mapping(uint256 => NGO) public NGOs;
     mapping(address => bool) donor;

    // Constructor sets the admin
    constructor(uint _count) {
        admin = msg.sender;
        idx = _count ;
    }

    // Function to register an NGO
    function Register(string calldata _uri) external {
        // Ensure the NGO is not already registered
        
        // require(!NGOs[i].isRegistered, "NGO already registered");

        // Initialize the NGO (only non-mapping fields)
        NGO storage newNGO = NGOs[idx]; // Get a reference to the NGO struct
        newNGO.uri = _uri;
        newNGO.owner = address(msg.sender);
        newNGO.totalDonor = 0;
       
        newNGO.totalValue = 0;
        newNGO.isRegistered = true;
        newNGO.blacklisted = false;
        ++idx;
    }


    function donate(uint _idx) external payable {
        require(NGOs[_idx].isRegistered , "Idx is not registered");
        require(msg.value > 0 , "Invalid value");
        NGO storage ngo = NGOs[_idx];
        ngo.totalValue +=msg.value;
        ngo.totalDonor ++;


    }
}
