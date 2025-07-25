# Identity Bridge - Cross-Platform Identity Linking

A self-sovereign identity verification smart contract built on the Stacks blockchain using Clarity. This contract enables users to create decentralized identities, manage claims, link external platforms, and build reputation in a trustless environment.

## Overview

Identity Bridge provides a comprehensive solution for digital identity management that puts users in complete control of their data while enabling trusted verification through an authorized network of verifiers.

### Key Features

- **Self-Sovereign Identity**: Users own and control their identity data
- **Cross-Platform Linking**: Connect identities across multiple platforms (Twitter, GitHub, LinkedIn, etc.)
- **Claim Management**: Add, verify, and manage personal claims with expiration
- **Reputation System**: Build and maintain reputation scores through verified activities
- **Authorized Verifiers**: Trusted entities can verify claims and update reputation
- **Emergency Controls**: Identity revocation and recovery mechanisms

## Smart Contract Functions

### User Functions

#### `create-identity()`
Creates a new decentralized identity for the caller.
- **Returns**: DID (Decentralized Identifier) string
- **Example**: `"did:stx:1000123"`

#### `add-claim(claim-type, claim-data, expires-at)`
Add a personal claim to your identity.
- **Parameters**:
  - `claim-type`: Type of claim (e.g., "email", "age", "location")
  - `claim-data`: The actual claim data
  - `expires-at`: Block height when claim expires
- **Example**: Add email claim that expires in 1000 blocks

#### `link-platform(platform, platform-id, verification-hash)`
Link your identity to an external platform.
- **Parameters**:
  - `platform`: Platform name (e.g., "twitter", "github")
  - `platform-id`: Your ID on that platform
  - `verification-hash`: Hash for verification proof
- **Use Case**: Link Twitter account @username to your DID

#### `unlink-platform(platform)`
Remove a platform link from your identity.
- **Parameters**:
  - `platform`: Platform to unlink

### Verifier Functions

#### `verify-claim(identity, claim-type)`
Verify a user's claim (authorized verifiers only).
- **Parameters**:
  - `identity`: Principal of the identity to verify
  - `claim-type`: Type of claim to verify
- **Effect**: Marks claim as verified and increases verifier's count

#### `update-reputation(identity, new-score)`
Update a user's reputation score (authorized verifiers only).
- **Parameters**:
  - `identity`: Principal of the identity
  - `new-score`: New reputation score (0-1000)

### Admin Functions

#### `add-verifier(verifier, name)`
Add an authorized verifier (contract owner only).
- **Parameters**:
  - `verifier`: Principal of the new verifier
  - `name`: Display name for the verifier

#### `revoke-verifier(verifier)`
Remove verifier authorization (contract owner only).

#### `revoke-identity(identity, reason)`
Emergency identity revocation (owner or identity holder only).

### Read-Only Functions

#### `get-identity(user)`
Retrieve complete identity information.
- **Returns**: Identity data including DID, creation time, reputation, etc.

#### `get-claim(identity, claim-type)`
Get specific claim information.
- **Returns**: Claim data, verifier, verification status, expiration

#### `is-claim-valid(identity, claim-type)`
Check if a claim is currently valid (verified and not expired).
- **Returns**: Boolean

#### `get-platform-link(identity, platform)`
Get platform linking information.

#### `get-reputation(identity)`
Get identity's current reputation score.

#### `get-stats()`
Get contract statistics (total identities, verifications, etc.).

## Data Structures

### Identity
```clarity
{
  did: (string-ascii 64),
  created-at: uint,
  updated-at: uint,
  is-active: bool,
  reputation-score: uint
}
```

### Claims
```clarity
{
  claim-data: (string-ascii 256),
  verifier: principal,
  verified-at: uint,
  expires-at: uint,
  is-verified: bool
}
```

### Platform Links
```clarity
{
  platform-id: (string-ascii 64),
  linked-at: uint,
  verification-hash: (buff 32),
  is-active: bool
}
```

## Usage Examples

### Creating an Identity
```clarity
;; Create your identity
(contract-call? .identity-bridge create-identity)
;; Returns: (ok "did:stx:1000123")
```

### Adding and Verifying Claims
```clarity
;; Add an email claim (expires in 1000 blocks)
(contract-call? .identity-bridge add-claim "email" "user@example.com" u1001000)

;; Verifier verifies the email claim
(contract-call? .identity-bridge verify-claim 'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM "email")
```

### Linking Social Media
```clarity
;; Link Twitter account
(contract-call? .identity-bridge link-platform 
  "twitter" 
  "username123" 
  0x1234567890abcdef...)

;; Later unlink if needed
(contract-call? .identity-bridge unlink-platform "twitter")
```

### Checking Identity Status
```clarity
;; Get full identity info
(contract-call? .identity-bridge get-identity 'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM)

;; Check if email claim is valid
(contract-call? .identity-bridge is-claim-valid 
  'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM 
  "email")
```

## Security Features

### Access Control
- **User Sovereignty**: Only identity owners can add claims and link platforms
- **Authorized Verifiers**: Only approved verifiers can verify claims and update reputation
- **Owner Controls**: Contract owner manages verifier authorization

### Data Integrity
- **Immutable Records**: All identity actions are permanently recorded
- **Expiration Management**: Claims can expire to ensure data freshness
- **Revocation Mechanism**: Emergency identity revocation with audit trail

### Privacy Protection
- **Minimal Data Storage**: Only essential data stored on-chain
- **User Control**: Users control what claims to add and when to reveal them
- **Selective Disclosure**: Users can choose which verifiers to trust

## Integration Guide

### For Applications
1. **Check Identity**: Use `get-identity()` to verify user has an identity
2. **Verify Claims**: Use `is-claim-valid()` to check specific claims
3. **Check Reputation**: Use `get-reputation()` for trust scoring
4. **Platform Verification**: Use `get-platform-link()` to verify external accounts

### For Verifiers
1. **Get Authorization**: Contract owner must add you as authorized verifier
2. **Verify Claims**: Review user submissions and call `verify-claim()`
3. **Maintain Quality**: Update reputation scores based on verification quality
4. **Track Statistics**: Monitor your verification count via `get-verifier()`

## Error Codes

- `u100`: Owner only operation
- `u101`: Identity/claim not found
- `u102`: Identity already exists
- `u103`: Unauthorized operation
- `u104`: Invalid signature
- `u105`: Claim expired

## Deployment

1. Deploy the contract to Stacks blockchain
2. Set up initial authorized verifiers
3. Configure frontend integration
4. Begin user onboarding


*Built on Stacks blockchain with Clarity smart contracts for maximum security and transparency.*