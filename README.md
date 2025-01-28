# FortuneWheel - Decentralized Random Reward System

## Overview

FortuneWheel is a transparent, decentralized reward distribution system built on the Stacks blockchain using Clarity smart contracts. It enables fair, verifiable random selection of multiple winners from a pool of participants, with configurable parameters and automated prize distribution.

## Features

- **Multi-Winner System**: Supports selecting multiple winners with configurable prize distribution
- **Verifiable Randomness**: Uses block information for transparent random number generation
- **Flexible Configuration**: Adjustable parameters for entry fees, minimum participants, and time locks
- **Automated Distribution**: Smart contract handles prize distribution automatically
- **Fair Play Mechanisms**: Built-in safeguards against manipulation
- **Scalable Design**: Supports up to 50 participants and 10 winners per game round

## Technical Specifications

### Core Parameters

- Maximum Participants per Round: 50
- Maximum Winners per Round: 10
- Default Entry Fee: 1 STX
- Minimum Entry Fee: 0.1 STX
- Maximum Entry Fee: 100 STX
- Default Time Lock: 100 blocks
- Time Lock Range: 50-1000 blocks

### Smart Contract Functions

#### Public Functions

1. `start-new-game()`
   - Initializes a new game round
   - Restricted to admin only
   - Returns: Game ID (uint)

2. `enter-game()`
   - Allows participation in current game
   - Requires entry fee payment
   - Returns: Success/failure status

3. `select-winners()`
   - Triggers winner selection and prize distribution
   - Requires minimum time lock and participants
   - Returns: List of winners with prizes

#### Read-Only Functions

1. `get-game-info(game-id: uint)`
   - Returns complete information about a specific game

2. `get-current-game()`
   - Returns information about the current active game

3. `get-player-entries(game-id: uint, player: principal)`
   - Returns number of entries for a specific player

4. `get-entry-fee()`
   - Returns current entry fee

5. `get-champion-count()`
   - Returns current number of winners per game

#### Admin Functions

1. `set-entry-fee(new-fee: uint)`
2. `set-min-participants(new-min: uint)`
3. `set-time-lock(new-lock: uint)`
4. `set-champion-count(new-count: uint)`

### Error Codes

- `ERR-UNAUTHORIZED (u100)`: Unauthorized access attempt
- `ERR-GAME-RUNNING (u101)`: Game already in progress
- `ERR-NO-ACTIVE-GAME (u102)`: No active game found
- `ERR-LOW-BALANCE (u103)`: Insufficient funds for entry
- `ERR-EMPTY-POOL (u105)`: Not enough participants
- `ERR-TIME-LOCK (u106)`: Time lock not expired
- `ERR-GAME-COMPLETE (u108)`: Game already completed
- `ERR-TOO-MANY-CHAMPIONS (u110)`: Champion count exceeds maximum

## Usage Guide

### For Participants

1. Check current game status and entry fee using `get-current-game()` and `get-entry-fee()`
2. Ensure your wallet has sufficient STX balance
3. Call `enter-game()` to participate
4. Monitor game progress through `get-game-info()`
5. Winners are automatically notified and receive prizes after selection

### For Administrators

1. Initialize new games with `start-new-game()`
2. Configure game parameters using admin functions
3. Monitor participation levels
4. Ensure proper time locks and participant minimums are met

## Security Features

- Time-locked execution
- Block-based randomness
- Admin-only configuration
- Input validation
- Balance checks
- Participant limits
- Automated prize distribution

## Prize Distribution

The prize pool is distributed among winners as follows:
- Base prize: Total pool divided equally among winners
- Bonus: Any remainder from division goes to first winner
- Automatic transfer upon winner selection

## Development and Testing

### Prerequisites

- Clarity CLI
- Stacks blockchain node (for deployment)
- STX testnet tokens (for testing)

### Deployment Steps

1. Clone the repository
2. Configure deployment parameters
3. Deploy to testnet for initial testing
4. Verify contract functionality
5. Deploy to mainnet

### Testing Guidelines

1. Test all error conditions
2. Verify random number generation
3. Test prize distribution
4. Verify admin functions
5. Test participant limits
6. Verify time locks

## Best Practices

1. Always verify transaction success
2. Monitor gas costs
3. Keep track of entry fees
4. Verify game status before participation
5. Review winner selection process
6. Monitor contract balance

## Contributing

Contributions are welcome! Please follow these steps:

1. Fork the repository
2. Create a feature branch
3. Commit your changes
4. Push to the branch
5. Create a Pull Request

## Support

For support and queries:
1. Open an issue in the repository
2. Check existing documentation
3. Review closed issues for similar problems
4. Follow contribution guidelines for major changes

## Disclaimer

This smart contract is provided as-is. Users should perform their own security audits and testing before deployment or use in production environments.