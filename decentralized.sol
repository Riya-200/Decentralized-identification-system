// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title Decentralized Identity Verification System
 * @dev A smart contract for managing decentralized digital identities with verification capabilities
 * @author Your Name
 */
contract DecentralizedIdentityVerification {
    
    // Structure to store identity information
    struct Identity {
        string name;
        string email;
        string documentHash; // IPFS hash of identity documents
        bool isVerified;
        address verifier;
        uint256 verificationTimestamp;
        bool isActive;
    }
    
    // Structure for verification requests
    struct VerificationRequest {
        address user;
        string documentHash;
        uint256 timestamp;
        bool isPending;
    }
    
    // State variables
    mapping(address => Identity) public identities;
    mapping(address => bool) public authorizedVerifiers;
    mapping(uint256 => VerificationRequest) public verificationRequests;
    
    address public owner;
    uint256 public nextRequestId;
    uint256 public verificationFee;
    
    // Events
    event IdentityRegistered(address indexed user, string name, string email);
    event VerificationRequested(address indexed user, uint256 requestId);
    event IdentityVerified(address indexed user, address indexed verifier);
    event VerifierAuthorized(address indexed verifier);
    event VerifierRevoked(address indexed verifier);
    
    // Modifiers
    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner can call this function");
        _;
    }
    
    modifier onlyVerifier() {
        require(authorizedVerifiers[msg.sender], "Only authorized verifiers can call this function");
        _;
    }
    
    modifier identityExists(address user) {
        require(bytes(identities[user].name).length > 0, "Identity does not exist");
        _;
    }
    
    /**
     * @dev Constructor sets the contract owner and initial verification fee
     */
    constructor() {
        owner = msg.sender;
        verificationFee = 0.01 ether; // Set initial verification fee
        nextRequestId = 1;
    }
    
    /**
     * @dev Core Function 1: Register a new identity
     * @param _name Full name of the user
     * @param _email Email address of the user
     * @param _documentHash IPFS hash of identity documents
     */
    function registerIdentity(
        string memory _name,
        string memory _email,
        string memory _documentHash
    ) external {
        require(bytes(_name).length > 0, "Name cannot be empty");
        require(bytes(_email).length > 0, "Email cannot be empty");
        require(bytes(_documentHash).length > 0, "Document hash cannot be empty");
        require(bytes(identities[msg.sender].name).length == 0, "Identity already exists");
        
        identities[msg.sender] = Identity({
            name: _name,
            email: _email,
            documentHash: _documentHash,
            isVerified: false,
            verifier: address(0),
            verificationTimestamp: 0,
            isActive: true
        });
        
        emit IdentityRegistered(msg.sender, _name, _email);
    }
    
    /**
     * @dev Core Function 2: Request identity verification
     * @param _documentHash Updated IPFS hash of verification documents
     */
    function requestVerification(string memory _documentHash) external payable identityExists(msg.sender) {
        require(msg.value >= verificationFee, "Insufficient verification fee");
        require(!identities[msg.sender].isVerified, "Identity already verified");
        require(bytes(_documentHash).length > 0, "Document hash cannot be empty");
        
        verificationRequests[nextRequestId] = VerificationRequest({
            user: msg.sender,
            documentHash: _documentHash,
            timestamp: block.timestamp,
            isPending: true
        });
        
        // Update document hash in identity
        identities[msg.sender].documentHash = _documentHash;
        
        emit VerificationRequested(msg.sender, nextRequestId);
        nextRequestId++;
    }
    
    /**
     * @dev Core Function 3: Verify an identity (only authorized verifiers)
     * @param _requestId The ID of the verification request
     * @param _approve Whether to approve or reject the verification
     */
    function verifyIdentity(uint256 _requestId, bool _approve) external onlyVerifier {
        require(verificationRequests[_requestId].isPending, "Request not pending or does not exist");
        
        VerificationRequest storage request = verificationRequests[_requestId];
        address userAddress = request.user;
        
        require(identities[userAddress].isActive, "User identity is not active");
        
        if (_approve) {
            identities[userAddress].isVerified = true;
            identities[userAddress].verifier = msg.sender;
            identities[userAddress].verificationTimestamp = block.timestamp;
            
            emit IdentityVerified(userAddress, msg.sender);
        }
        
        // Mark request as processed
        request.isPending = false;
    }
    
    /**
     * @dev Authorize a new verifier (only owner)
     * @param _verifier Address of the verifier to authorize
     */
    function authorizeVerifier(address _verifier) external onlyOwner {
        require(_verifier != address(0), "Invalid verifier address");
        require(!authorizedVerifiers[_verifier], "Verifier already authorized");
        
        authorizedVerifiers[_verifier] = true;
        emit VerifierAuthorized(_verifier);
    }
    
    /**
     * @dev Revoke verifier authorization (only owner)
     * @param _verifier Address of the verifier to revoke
     */
    function revokeVerifier(address _verifier) external onlyOwner {
        require(authorizedVerifiers[_verifier], "Verifier not authorized");
        
        authorizedVerifiers[_verifier] = false;
        emit VerifierRevoked(_verifier);
    }
    
    /**
     * @dev Get identity information
     * @param _user Address of the user
     * @return name The user's full name
     * @return email The user's email address
     * @return documentHash IPFS hash of identity documents
     * @return isVerified Whether the identity is verified
     * @return verifier Address of the verifier who verified the identity
     * @return verificationTimestamp Timestamp when verification occurred
     * @return isActive Whether the identity is currently active
     */
    function getIdentity(address _user) external view returns (
        string memory name,
        string memory email,
        string memory documentHash,
        bool isVerified,
        address verifier,
        uint256 verificationTimestamp,
        bool isActive
    ) {
        Identity memory identity = identities[_user];
        return (
            identity.name,
            identity.email,
            identity.documentHash,
            identity.isVerified,
            identity.verifier,
            identity.verificationTimestamp,
            identity.isActive
        );
    }
    
    /**
     * @dev Update verification fee (only owner)
     * @param _newFee New verification fee in wei
     */
    function updateVerificationFee(uint256 _newFee) external onlyOwner {
        verificationFee = _newFee;
    }
    
    /**
     * @dev Withdraw contract balance (only owner)
     */
    function withdraw() external onlyOwner {
        uint256 balance = address(this).balance;
        require(balance > 0, "No funds to withdraw");
        
        payable(owner).transfer(balance);
    }
    
    /**
     * @dev Deactivate an identity (only owner or user themselves)
     * @param _user Address of the user whose identity to deactivate
     */
    function deactivateIdentity(address _user) external {
        require(msg.sender == owner || msg.sender == _user, "Unauthorized");
        require(identities[_user].isActive, "Identity already inactive");
        
        identities[_user].isActive = false;
    }
    
    /**
     * @dev Check if an address has a verified identity
     * @param _user Address to check
     * @return bool indicating verification status
     */
    function isVerifiedUser(address _user) external view returns (bool) {
        return identities[_user].isVerified && identities[_user].isActive;
    }
}
