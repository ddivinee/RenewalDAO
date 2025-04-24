# Terra Renewal DAO

A decentralized autonomous organization built on the Stacks blockchain that funds sustainable farming practices through community governance.

## Overview

Terra Renewal DAO connects regenerative farmers with supporters to fund sustainable agriculture projects. The DAO uses a token-based governance system that allows members to propose, vote on, and fund initiatives that promote soil health, biodiversity, and sustainable farming practices.

## Features

- **Decentralized Governance**: Token holders participate in democratic decision-making
- **Transparent Funding**: All proposals and fund allocations are recorded on the blockchain
- **Sustainable Focus**: Supports farming practices that regenerate rather than deplete natural resources
- **Community Driven**: Farmers and environmental supporters collaborate to direct resources

## Smart Contract Functionality

The Terra Renewal DAO is powered by a Clarity smart contract that provides the following functionality:

### Governance Token System
- **Token Distribution**: Initial supply of 1,000,000 tokens
- **Token Transfer**: Members can transfer tokens to other participants
- **Token-Weighted Voting**: Voting power is proportional to token holdings

### Proposal Management
- **Proposal Creation**: Farmers can submit funding requests with detailed project information
- **Required Information**: Title, description, farm location, funding amount, and sustainable practices
- **Minimum Threshold**: Requires 1,000 tokens to submit proposals (prevents spam)

### Voting System
- **Democratic Process**: All token holders can vote on proposals
- **Voting Period**: ~1 day (144 blocks at 10-minute block time)
- **Execution Delay**: ~12 hours after voting ends before funds can be disbursed

### Fund Distribution
- **Secure Transfer**: Approved proposals receive STX tokens directly
- **Accountable Allocation**: Only contract owner can release funds to approved proposals

## How to Use

### For Farmers

1. **Acquire Tokens**: Join the DAO by acquiring governance tokens
2. **Submit Proposal**: Create a proposal detailing your sustainable farming project
3. **Engage Community**: Discuss your proposal with the community to gather support
4. **Implement Project**: If approved, receive funding and implement your sustainable practices

### For Supporters

1. **Acquire Tokens**: Join the DAO by acquiring governance tokens
2. **Vote on Proposals**: Use your tokens to vote on projects you believe in
3. **Transfer Tokens**: Support specific farmers by transferring tokens to them
4. **Propose Initiatives**: Suggest community-wide programs or criteria for funding

## Technical Implementation

### Contract Deployment

To deploy the Terra Renewal DAO contract:

```bash
# Install Clarinet (Clarity development tool)
brew install clarinet

# Create a new project
clarinet new terra-renewal-dao
cd terra-renewal-dao

# Add the contract to the project
cp path/to/terra-renewal.clar contracts/

# Test the contract
clarinet test

# Deploy to testnet
clarinet deploy --testnet
```

### Key Contract Functions

- `create-proposal`: Submit a new farming project for consideration
- `vote-on-proposal`: Cast a vote on an active proposal
- `finalize-proposal`: Conclude voting and determine approval status
- `release-funds`: Transfer approved funds to project creators
- `transfer`: Move tokens between DAO members
- `mint-tokens`: Add new tokens to the ecosystem (admin only)

## Governance Parameters

The following parameters control the DAO's operation:

- **Voting Period**: 144 blocks (~1 day)
- **Execution Delay**: 72 blocks (~12 hours)
- **Minimum Proposal Amount**: 1,000 tokens
- **Initial Token Supply**: 1,000,000 tokens

## Future Development

- Integration with real-world impact verification systems
- Carbon credit generation for qualifying projects
- Expanded governance models with specialized roles
- Mobile app for farmers to track and report project progress
- Educational resources on regenerative agriculture practices

## Contributing

We welcome contributions from developers, farmers, environmentalists, and anyone passionate about sustainable agriculture. Please submit pull requests or reach out through our community channels.
