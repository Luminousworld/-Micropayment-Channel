⚡ State Channel Smart Contract (Clarity)
A Clarity smart contract for implementing payment channels (also known as state channels) on the Stacks blockchain. This allows two parties to transact off-chain with periodic updates, reducing on-chain fees and congestion, and only settling final balances on-chain.

🧠 Features
Open a new payment channel between two participants.

Secure deposit mechanism using STX transfers.

Off-chain state updates with signed messages.

On-chain dispute resolution through a challenge period.

Cooperative or forced closure of the channel.

📜 Contract Summary
Constants
clojure
Copy
Edit
ERR_UNAUTHORIZED              ;; u1
ERR_CHANNEL_NOT_OPEN         ;; u2
ERR_CHANNEL_ALREADY_OPEN     ;; u3
ERR_INVALID_SIGNATURE        ;; u4
ERR_INSUFFICIENT_BALANCE     ;; u5
ERR_CHALLENGE_PERIOD_ACTIVE  ;; u6
ERR_INVALID_STATE            ;; u7
CHALLENGE_PERIOD_BLOCKS      ;; u144 (~24 hours at 10min blocks)
Data Structure
channels Map

Each channel is identified by a channel-id (uint) and stores:

participant-1, participant-2: Principals

balance-1, balance-2: STX balances

nonce: Version of the latest state

state: "OPEN", "ACTIVE", "CLOSING"

challenge-height: Block height for timeout

🧩 Key Functions
open-channel(channel-id, participant-2, initial-balance-1, initial-balance-2)
Called by participant-1.

Locks in initial-balance-1 from the caller.

Initializes the channel in "OPEN" state.

join-channel(channel-id)
Called by participant-2.

Deposits balance-2 and activates the channel.

update-channel-state(channel-id, new-balance-1, new-balance-2, new-nonce, signature-1, signature-2)
Verifies updated off-chain state.

Requires both participants’ signatures.

Ensures balances and nonce are consistent.

initiate-close(channel-id)
Starts the closing process and sets a challenge timeout.

Channel state set to "CLOSING".

close-channel(channel-id)
After challenge period, finalizes channel and transfers STX back.

Deletes the channel from storage.

force-close-with-state(channel-id, submit-balance-1, submit-balance-2, submit-nonce, signature-1, signature-2)
If a newer state exists, either participant can submit it during the challenge period.

Allows final settlement before timeout ends.

🔐 Security Considerations
All updates must be signed by both participants.

Replay protection via nonce.

Funds cannot be withdrawn until the challenge period ends or both participants agree.

🚀 Usage
This contract is designed to be used in dApps or wallets that support off-chain signed state exchanges (e.g., micro-payments, games, etc.).

Example Workflow:
participant-1 calls open-channel.

participant-2 calls join-channel.

Off-chain updates are exchanged and signed.

Any participant can call update-channel-state.

Either can call initiate-close to start dispute period.

If needed, submit force-close-with-state.

After timeout, call close-channel.

🛠️ Requirements
Clarity Language

Stacks blockchain (e.g., testnet)

STX wallet integration (for signing messages)

📂 License
MIT License






