# TossIt 🪙

A simple and educational Ethereum smart contract for a coin toss game built with [Foundry](https://getfoundry.sh/).

## Overview

TossIt is a decentralized coin toss game where two players can join and compete in a simple heads-or-tails game. The first player chooses heads or tails, and the second player automatically gets the opposite choice. The winner is determined by a simulated coin toss using blockchain randomness.

## Features

- **Simple Game Mechanics**: Easy-to-understand heads-or-tails gameplay
- **Two-Player System**: Supports exactly two players per game
- **Automatic Side Assignment**: Second player automatically gets the opposite choice
- **Event Logging**: Comprehensive event emission for game tracking
- **View Functions**: Easy access to game state and player information
- **Educational Focus**: Well-documented code for learning purposes

## Game Flow

1. **Game Initialization**: The first player deploys the contract and chooses heads or tails
2. **Player Joining**: The second player joins and automatically gets the opposite choice
3. **Coin Toss**: Either player can trigger the coin toss to determine the winner
4. **Winner Declaration**: The player whose choice matches the toss result wins

## Smart Contract Functions

### Core Functions
- `joinGame()` - Allows the second player to join the game
- `tossCoin()` - Simulates a coin toss and determines the winner
- `joinGameAndTossCoin()` - Combines joining and tossing in one transaction

### View Functions
- `getGameDetails()` - Returns complete game state information
- `getPlayerDetails(bool isPlayer1)` - Returns details for a specific player

### Events
- `JoinedGame(address indexed player1, address indexed player2)` - Emitted when the second player joins
- `GameOutcome(address indexed winner, bool outcome)` - Emitted when the game concludes

## Technology Stack

- **Solidity**: ^0.8.24
- **Foundry**: For development, testing, and deployment
- **Forge Standard Library**: For testing utilities

## Prerequisites

- [Foundry](https://getfoundry.sh/) installed on your system
- Basic knowledge of Solidity and Ethereum development

## Installation

1. Clone the repository:
```bash
git clone <repository-url>
cd TossIt
```

2. Install dependencies:
```bash
forge install
```

## Usage

### Building the Contract

```bash
forge build
```

### Running Tests

```bash
forge test
```

For verbose test output:
```bash
forge test -vv
```

### Formatting Code

```bash
forge fmt
```

### Gas Snapshots

```bash
forge snapshot
```

### Local Development

Start a local Anvil instance:
```bash
anvil
```

### Deployment

Deploy to a local network:
```bash
forge script script/CointToss.s.sol:CoinTossScript --rpc-url http://localhost:8545 --private-key <your_private_key> --broadcast
```

Deploy to a testnet/mainnet:
```bash
forge script script/CointToss.s.sol:CoinTossScript --rpc-url <your_rpc_url> --private-key <your_private_key> --broadcast
```

## Contract Architecture

### Data Structures

- `PlayerDetails`: Stores player address and their choice (heads/tails)
- `Game`: Contains complete game state including both players, winner, and outcome
- `GameInitialization`: Used for contract deployment with initial player choice

### Security Considerations

⚠️ **Important**: This contract is designed for educational purposes only. It uses a simple pseudo-randomness mechanism based on block timestamp, which is not suitable for production use. For real-world applications, consider using:

- Chainlink VRF for verifiable randomness
- Commit-reveal schemes
- Multi-party computation (MPC) solutions

## Testing

The contract includes comprehensive tests covering:

- Game joining functionality
- Coin toss mechanics
- Combined join and toss operations
- Error conditions and edge cases
- Access control validation

Run the test suite:
```bash
forge test
```

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests for new functionality
5. Ensure all tests pass
6. Submit a pull request

## License

see the LICENSE file for details.

## Author

**Bruno Campos** - [bhncampos@gmail.com](mailto:bhncampos@gmail.com)

## Disclaimer

This smart contract is provided for educational purposes only. It has not been audited and should not be used in production environments where security and fairness are critical requirements.
