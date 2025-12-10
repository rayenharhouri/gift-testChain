# Testing Setup Guide - Foundry vs Hardhat

## Option 1: Foundry (Recommended for Smart Contracts)

### Installation
```bash
# Install Foundry
curl -L https://foundry.paradigm.xyz | bash
~/.foundry/bin/foundryup

# Verify installation
forge --version
cast --version
```

### Initialize Project
```bash
cd /home/fsociety/GIFT
forge init . --force
```

### Project Structure
```
GIFT/
├── src/
│   └── GoldAssetToken.sol
├── test/
│   └── GoldAssetToken.t.sol
├── foundry.toml
└── lib/
    └── openzeppelin-contracts/
```

### Install Dependencies
```bash
forge install OpenZeppelin/openzeppelin-contracts
```

### Update foundry.toml
```toml
[profile.default]
src = "contracts"
out = "out"
libs = ["lib"]
solc_version = "0.8.20"
```

### Run Tests
```bash
forge test
forge test -v  # Verbose
forge test --match-path "test/GoldAssetToken.t.sol" -vv
```

---

## Option 2: Hardhat (More Ecosystem Tools)

### Installation
```bash
cd /home/fsociety/GIFT
npm init -y
npm install --save-dev hardhat @nomicfoundation/hardhat-toolbox
npx hardhat
# Select: Create a JavaScript project
```

### Project Structure
```
GIFT/
├── contracts/
│   └── GoldAssetToken.sol
├── test/
│   └── GoldAssetToken.js
├── hardhat.config.js
├── package.json
└── node_modules/
```

### Install Dependencies
```bash
npm install --save-dev @openzeppelin/contracts
npm install --save-dev @nomicfoundation/hardhat-ethers ethers
```

### Update hardhat.config.js
```javascript
require("@nomicfoundation/hardhat-toolbox");

module.exports = {
  solidity: "0.8.20",
  networks: {
    hardhat: {
      chainId: 43214,
    },
  },
};
```

### Run Tests
```bash
npx hardhat test
npx hardhat test --grep "mint"
```

---

## Comparison

| Feature | Foundry | Hardhat |
|---------|---------|---------|
| Language | Solidity | JavaScript/TypeScript |
| Speed | Fast | Slower |
| Gas Analysis | Built-in | Plugin |
| Debugging | Good | Excellent |
| Ecosystem | Growing | Mature |
| Learning Curve | Steep | Gentle |

---

## Recommendation

**Use Foundry** for:
- Pure smart contract testing
- Gas optimization analysis
- Fast iteration

**Use Hardhat** for:
- Integration testing with backend
- Complex deployment scripts
- Team familiarity with JavaScript

---

## Quick Start (Foundry)

```bash
# 1. Install Foundry
curl -L https://foundry.paradigm.xyz | bash
~/.foundry/bin/foundryup

# 2. Initialize
cd /home/fsociety/GIFT
forge init . --force

# 3. Install OpenZeppelin
forge install OpenZeppelin/openzeppelin-contracts

# 4. Update foundry.toml
# Change src = "src" to src = "contracts"

# 5. Run tests
forge test -vv
```

Which would you prefer?
