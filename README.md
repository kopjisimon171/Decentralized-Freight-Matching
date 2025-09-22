# 🚛 Decentralized Freight Matching Platform

A trustless, blockchain-based marketplace connecting cargo shippers with independent drivers on the Stacks blockchain.

## 🎯 Overview

This smart contract eliminates intermediaries in freight logistics by providing:
- **Direct connections** between shippers and drivers
- **Stake-backed commitments** ensuring reliability
- **Automated payments** after delivery confirmation
- **Reputation system** tracking performance
- **Dispute resolution** for edge cases

## ✨ Key Features

### 🏗️ Core Functionality
- **Job Posting**: Shippers create freight jobs with payment escrow
- **Job Acceptance**: Drivers accept jobs by staking required amount
- **Delivery Tracking**: Status updates from pickup to completion
- **Automated Payments**: Funds released upon successful delivery
- **Timeout Handling**: Automatic job failure after delivery window expires

### 🛡️ Trust & Safety
- **Reputation Scoring**: Performance-based ratings for all users
- **Penalty System**: Failed deliveries impact reputation and forfeit stakes
- **Dispute Resolution**: Mediation system for conflicts
- **Stake Requirements**: Minimum commitment ensures serious participation

## 🚀 Getting Started

### Prerequisites
- [Clarinet](https://github.com/hirosystems/clarinet) installed
- STX tokens for testing

### Installation

```bash
git clone https://github.com/kopjisimon171/Decentralized-Freight-Matching
cd Decentralized-Freight-Matching
clarinet console
```

## 📋 Usage Guide

### For Shippers 📦

#### 1. Post a Job
```clarity
(contract-call? .Decentralized-Freight-Matching post-job
  "123 Main St, City A"        ;; pickup-location
  "456 Oak Ave, City B"        ;; delivery-location
  u5000000                     ;; payment-amount (5 STX)
  u1000000                     ;; stake-required (1 STX minimum)
  "Fragile electronics - handle with care"  ;; description
)
```

#### 2. Cancel Job (if not accepted)
```clarity
(contract-call? .Decentralized-Freight-Matching cancel-job u1)
```

#### 3. Handle Driver Timeout
```clarity
(contract-call? .Decentralized-Freight-Matching handle-timeout u1)
```

### For Drivers 🚚

#### 1. Accept a Job
```clarity
(contract-call? .Decentralized-Freight-Matching accept-job u1)
```

#### 2. Confirm Pickup
```clarity
(contract-call? .Decentralized-Freight-Matching confirm-pickup u1)
```

#### 3. Confirm Delivery
```clarity
(contract-call? .Decentralized-Freight-Matching confirm-delivery u1)
```

### For Both Parties ⚖️

#### Create Dispute
```clarity
(contract-call? .Decentralized-Freight-Matching create-dispute 
  u1 "Package was damaged during transit")
```

### Read-Only Functions 📊

#### Check Job Details
```clarity
(contract-call? .Decentralized-Freight-Matching get-job u1)
```

#### View User Profile
```clarity
(contract-call? .Decentralized-Freight-Matching get-user-profile 'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM)
```

#### Check Contract Balance
```clarity
(contract-call? .Decentralized-Freight-Matching get-contract-balance)
```

## 🔧 Contract Constants

| Constant | Value | Description |
|----------|--------|-------------|
| `MIN_STAKE` | 1,000,000 μSTX | Minimum stake requirement |
| `PLATFORM_FEE_PERCENT` | 2% | Platform fee on successful deliveries |
| `DELIVERY_TIMEOUT_BLOCKS` | 1,440 blocks | ~24 hours delivery window |
| `DISPUTE_TIMEOUT_BLOCKS` | 2,880 blocks | ~48 hours dispute resolution |

## 📈 Job Status Flow

```
posted → accepted → in-transit → completed ✅
   ↓         ↓          ↓
cancelled   failed    disputed
```

## 🎖️ Reputation System

- **Initial Score**: 100 (perfect)
- **Calculation**: `(completed_jobs * 100) / (completed_jobs + failed_jobs)`
- **Impact**: Higher reputation = more trustworthy partner
- **Tracking**: Completed jobs, failed jobs, total earnings

## 🧪 Testing

```bash
npm install
npm test
```

## 🛠️ Development

### Run Local Testnet
```bash
clarinet integrate
```

### Check Contract Syntax
```bash
clarinet check
```

### Console Testing
```bash
clarinet console
```

## 📄 Contract Functions

### Public Functions
- `post-job` - Create new freight job
- `accept-job` - Accept available job
- `confirm-pickup` - Mark pickup complete
- `confirm-delivery` - Complete delivery and release payment
- `cancel-job` - Cancel unaccepted job
- `handle-timeout` - Process expired deliveries
- `create-dispute` - Initiate dispute process
- `resolve-dispute` - Admin dispute resolution

### Read-Only Functions
- `get-job` - Retrieve job details
- `get-user-profile` - Get user reputation data
- `get-dispute` - View dispute information
- `get-job-stake` - Check stake details
- `get-contract-balance` - View contract STX balance
- `get-job-counter` - Total jobs created
- `get-dispute-counter` - Total disputes filed

## 🔐 Security Features

- ✅ **Authorization checks** for all actions
- ✅ **Balance verification** before transfers
- ✅ **Status validation** preventing invalid state changes
- ✅ **Timeout protection** against stuck jobs
- ✅ **Stake forfeiture** for failed deliveries

## 💡 Future Enhancements

- 🌍 GPS oracle integration for automatic delivery confirmation
- 📱 Mobile app integration
- 🏪 Multi-currency support
- 📊 Advanced analytics dashboard
- 🤝 Driver/shipper matching algorithm

## 📞 Support

For questions, issues, or contributions, please open an issue on GitHub or contact the development team.

---
*Built with ❤️ for the decentralized logistics future*
