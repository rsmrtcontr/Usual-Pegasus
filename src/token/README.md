# USD0

## High-Level Overview

This section provides an overview of the USD0 smart contract. The USD0 contract is designed to manage a USD0 ERC20 Token, implementing functionalities for minting, burning, and transfer operations while incorporating blacklist checks to restrict these operations to authorized addresses.

## Contract Summary

USD0 is an ERC-20 compliant token that integrates additional security and access control features to enhance its governance and usability. It inherits functionalities from ERC20PausableUpgradable and ERC20PermitUpgradeable to support permit-based approvals and pausability.

### Inherited Contracts

- **ERC20PausableUpgradeable**: Extends ERC20 to support pausability
- **ERC20PermitUpgradeable**: Extends ERC20 to support gasless transactions through signed approvals.

### ERC20PausableUpgradeable

Standard OpenZeppelin Implementation.

### ERC20PermitUpgradeable

Standard OpenZeppelin Implementation.

## Functionality Breakdown

### Key Functionalities

- **Minting**: Tokens can be minted to an address, subject to role checks.
- **Burning**: Tokens can be burned from an address, also subject to role checks.
- **Transfers**: Only not blacklisted addresses can send or receive tokens.

## Functions Description

### Public/External Functions

- **pause()**: Pauses all token transfer operations; callable only by the admin.
- **unpause()**: Resumes all token transfer operations; also callable only by the admin.
- **transfer(address to, uint256 amount)**: Transfers tokens to a non-blacklisted address.
- **transferFrom(address sender, address to, uint256 amount)**: Transfers tokens from one non-blacklisted address to another.
- **mint(address to, uint256 amount)**: Mints tokens to a non-blacklisted address if the caller has the `USD0_MINT` role.
- **burn(uint256 amount)** and **burnFrom(address account, uint256 amount)**: Burns tokens from an address, requiring the `USD0_BURN` role.

## Constants

- **CONTRACT_REGISTRY_ACCESS**: This constant is used to define the address of the registry access contract
- **DEFAULT_ADMIN_ROLE**: This constant is used to define the default admin role for the contract.
- **USD0_MINT**: Role required to mint new tokens.
- **USD0_BURN**: Role required to burn tokens.

## Safeguards Implementation

- **Pausability**: Ensures that token transfers can be halted in case of emergency.
- **Role-Based Access Control**: Restricts sensitive actions to addresses with appropriate roles.
- **Blacklist Enforcement**: Ensures that only non-malicious addresses can participate in the token economy.

## Possible Attack Vectors

- **Reentrancy on minting and burning**: Although not directly vulnerable, external calls should be monitored.
- **Denial of Service by blocking blacklist management**: If the admin key is compromised.

## Potential Risks

- **Centralization of Control**: Heavy reliance on admin roles for critical functionality.
- **Smart Contract Bugs**: In complex interactions with inherited contracts and role management.

## Potential Manipulations

- **Blacklist Manipulation**: An admin could potentially manipulate the blacklist to exclude legitimate users.

## Conclusion

The USD0 contract is structured with security features for role management and blacklisting. However, centralization risks and potential administrative overreach should be mitigated through additional safeguards and decentralization of control where possible.

# USD0PP

## **High-Level Overview**

This smart contract is designed to manage bond-like financial instruments for the UsualDAO ecosystem. It provides functionality for minting, transferring, and unwrapping bonds. The contract is built to comply with ERC20 standards and includes security features to prevent common vulnerabilities.

## **Contract Summary**

The contract provides a robust bond management system. It inherits from ERC20PermitUpgradeable for token permit functionality, ReentrancyGuardUpgradeable for reentrancy attack protection, and IUsd0PP for bond-specific functionalities.

## **Inherited Contracts**

- **ERC20PausableUpgradeable**: Allows authorized addresses to pause all contract functionalities in case of an emergency.
- **ERC20PermitUpgradeable**: This contract provides token permit functionality, allowing users to permit other addresses to spend their tokens.
- **ReentrancyGuardUpgradeable**: This contract provides protection against reentrancy attacks, ensuring that functions cannot be called recursively in an unintended way.
- **IUsd0PP**: This is the interface contract that defines the bond-specific functionalities.

## **Functionality Breakdown**

The contract flow begins with the initialization of the bond parameters and related registry and token information. Bonds can be minted, transferred, and unwrapped. The contract also allows for emergency withdrawals of the underlying token.

## **Functions Description**

### **Public/External Functions (non-view / non-pure)**

- **initialize(address registryContract, string memory name_, string memory symbol_, uint256 startTime)**: This function initializes the contract with bond parameters and related registry and token information.
- **pause()**: This function pauses all token transfer functionalities in case of an emergency.
- **unpause()**: This function unpauses all token transfer functionalities after an emergency.
- **mint(uint256 amountUsd0)**: This function mints new bonds. It takes one parameter, the amount of collateral token to be locked in the bond.
- **mintWithPermit(uint256 amountUsd0, uint256 deadline, uint8 v, bytes32 r, bytes32 s)**: This function mints new bonds with a permit signature.
- **unwrap()**: This function unwraps the bonds and transfers the underlying collateral token to the user.
- **transfer(address recipient, uint256 amount)**: This function transfers bonds from the sender to the recipient.
- **transferFrom(address sender, address recipient, uint256 amount)**: This function transfers bonds from the sender to the recipient on behalf of the sender.
- **emergencyWithdraw(address safeAccount)**: This function allows for the emergency withdrawal of the underlying collateral token.

## **Constants **

- **DEFAULT_ADMIN_ROLE**: This constant is used to define the default admin role for the contract.
- **CONTRACT_USD0**: This constant is used to define the address of the USD0 contract.
- **CONTRACT_REGISTRY_ACCESS**: This constant is used to define the address of the registry access contract.
- **BOND_DURATION_FOUR_YEAR**: This constant is used to define the duration of the bond period.

## **Safeguards Implementation**

- **ReentrancyGuardUpgradeable**: This contract provides protection against reentrancy attacks.
- **SafeERC20**: This library is used for safe token transfers, preventing loss of tokens due to incorrect contract behavior.
- **Check-Effects-Interactions Pattern**: This pattern is implemented to prevent reentrancy attacks. State changes are made before external calls, ensuring that the contract's state is updated before any external interaction.

## **Possible Attack Vectors**

- **Reentrancy on mint function**: There is a potential for attackers to re-enter the mint function before it completes, leading to unauthorized bond minting.
- **Unauthorized emergency withdrawal**: If the access control for the emergency withdrawal function is not properly implemented, unauthorized users could withdraw the underlying collateral token.

## **Potential Risks**

- **Risk of Loss**: If the emergency withdrawal function is called, the underlying collateral token could be lost if the recipient address is incorrect or malicious.
- **Bond Not Finished**: If the unwrap function is called before the bond period is finished, the function will revert.
