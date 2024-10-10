// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.27;

contract NGO_Funding {
  
    address public admin;

    // Struct to define NGO properties
    struct NGO {
        string uri;            
        address owner;          
        uint256 totalValue;    
        bool isRegistered;        
        bool blacklisted;      
        mapping(address => bool) donor;
    }

   
    mapping(address => NGO) public NGOs;

    // Constructor sets the admin
    constructor() {
        admin = msg.sender;
    }

    // Function to register an NGO
    function Register(string calldata _uri) external {
        // Ensure the NGO is not already registered
        require(!NGOs[msg.sender].isRegistered, "NGO already registered");

        // Initialize the NGO (only non-mapping fields)
        NGO storage newNGO = NGOs[msg.sender]; // Get a reference to the NGO struct
        newNGO.uri = _uri;
        newNGO.owner = msg.sender;
        newNGO.totalValue = 0;
        newNGO.isRegistered = true;
        newNGO.blacklisted = false;
    }


    fucntion Donate() external payable {
        
    }
}
