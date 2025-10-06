# 🏛️ On-Chain Will Executor

A decentralized smart contract system for executing digital inheritance with multisig verification on the Stacks blockchain. This contract enables secure, trustless will execution after death confirmation by designated executors.

## 🌟 Features

- 📝 **Create Digital Wills**: Set up inheritance distribution with multiple beneficiaries
- 👥 **Multisig Verification**: Require multiple executor confirmations before execution
- 💰 **Automatic Distribution**: Seamlessly distribute STX tokens to beneficiaries
- 🔒 **Secure Execution**: Trustless execution once death is confirmed
- ⚡ **Will Management**: Update executors or revoke wills when needed
- 📊 **Transparent Tracking**: Monitor confirmation status and contract state

## 🚀 Quick Start

### Creating a Will

```clarity
(contract-call? .will-executor create-will
  (list 
    { recipient: 'SP1ABC..., amount: u1000000 }
    { recipient: 'SP2DEF..., amount: u500000 }
  )
  (list 'SP3GHI... 'SP4JKL... 'SP5MNO...)
  u2
)
```

### Funding Your Will

```clarity
(contract-call? .will-executor fund-will 'SP1TESTATOR...)
```

### Confirming Death (Executors Only)

```clarity
(contract-call? .will-executor confirm-death 'SP1TESTATOR...)
```

### Executing the Will

```clarity
(contract-call? .will-executor execute-will 'SP1TESTATOR...)
```

## 📋 Contract Functions

### Public Functions

| Function | Description |
|----------|-------------|
| `create-will` | 📝 Create a new will with beneficiaries and executors |
| `fund-will` | 💰 Fund the will with STX tokens |
| `confirm-death` | ☠️ Executor confirms the testator's death |
| `execute-will` | ⚡ Execute will after sufficient confirmations |
| `revoke-will` | 🗑️ Cancel will and withdraw funds |
| `update-will-executors` | 🔄 Update executor list and requirements |

### Read-Only Functions

| Function | Description |
|----------|-------------|
| `get-will` | 📖 Retrieve will details |
| `get-confirmation-count` | 🔢 Get current death confirmations |
| `is-will-ready-for-execution` | ✅ Check if will can be executed |
| `get-contract-balance` | 💳 View total contract balance |

## 🛠️ Usage Examples

### 1. Setting Up a Family Will

```clarity
;; Create will for family inheritance
(contract-call? .will-executor create-will
  (list 
    { recipient: 'SP1SPOUSE..., amount: u5000000 }
    { recipient: 'SP2CHILD1..., amount: u2500000 }
    { recipient: 'SP3CHILD2..., amount: u2500000 }
  )
  (list 'SP4LAWYER... 'SP5DOCTOR... 'SP6FRIEND...)
  u2
)
```

### 2. Business Partnership Will

```clarity
;; Create will for business assets
(contract-call? .will-executor create-will
  (list 
    { recipient: 'SP1PARTNER..., amount: u10000000 }
  )
  (list 'SP2ACCOUNTANT... 'SP3LAWYER...)
  u2
)
```

## 🔐 Security Features

- ✅ **Multisig Protection**: Prevents single point of failure
- ✅ **Executor Validation**: Only designated executors can confirm death
- ✅ **Double-spend Prevention**: Wills can only be executed once
- ✅ **Owner Controls**: Only testator can modify or revoke will
- ✅ **Transparent Process**: All confirmations are publicly verifiable

## 📊 Error Codes

| Code | Description |
|------|-------------|
| `u100` | Unauthorized access |
| `u101` | Will not found |
| `u102` | Will already exists |
| `u103` | Invalid beneficiary |
| `u104` | Will already executed |
| `u105` | Insufficient confirmations |
| `u106` | Already confirmed |
| `u107` | Invalid executor |

## 🧪 Testing

Deploy and test using Clarinet:

```bash
clarinet console
```

```clarity
;; Test will creation
(contract-call? .will-executor create-will 
  (list { recipient: 'ST1BENEFICIARY, amount: u1000 })
  (list 'ST1EXECUTOR)
  u1
)
```

## 🤝 Contributing

1. Fork the repository
2. Create your feature branch
3. Test thoroughly with Clarinet
4. Submit a pull request

## 📄 License

This project is open source and available under the MIT License.

---

*Built with ❤️ for the Stacks ecosystem*
```

**Git Commit Message:**
```
feat: implement on-chain will executor with multisig death verification
```

**GitHub Pull Request Title:**
```
🏛️ Add On-Chain Will Executor Smart Contract with Multisig Verification
```

**GitHub Pull Request Description:**
```
## 📋 Summary
Added a comprehensive on-chain will execution system that enables secure digital inheritance through multisig verification.

## ✨ Features Added
- **Digital Will Creation**: Users can create wills with multiple beneficiaries and STX distribution amounts
- **Multisig Death Verification**: Requires multiple designated executors to confirm death before execution
- **Automatic Asset Distribution**: Seamlessly distributes STX tokens to beneficiaries upon execution
- **Will Management**: Support for updating executors, revoking wills, and funding management
- **Security Controls**: Comprehensive error handling and authorization checks

## 🔧 Technical Implementation
- Complete Clarity smart
