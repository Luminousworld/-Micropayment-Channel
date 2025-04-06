
;; Constants
(define-constant ERR_UNAUTHORIZED (err u1))
(define-constant ERR_CHANNEL_NOT_OPEN (err u2))
(define-constant ERR_CHANNEL_ALREADY_OPEN (err u3))
(define-constant ERR_INVALID_SIGNATURE (err u4))
(define-constant ERR_INSUFFICIENT_BALANCE (err u5))
(define-constant ERR_CHALLENGE_PERIOD_ACTIVE (err u6))
(define-constant ERR_INVALID_STATE (err u7))
(define-constant CHALLENGE_PERIOD_BLOCKS u144) ;; ~24 hours at 10 min blocks

;; Data structures
(define-map channels
  {channel-id: uint}
  {
    participant-1: principal,
    participant-2: principal,
    balance-1: uint,
    balance-2: uint,
    nonce: uint,
    state: (string-ascii 20),
    challenge-height: uint
  }
)

;; Private functions
(define-private (verify-signature (message (buff 128)) (signature (buff 65)) (signer principal))
  (is-eq (principal-of? (unwrap-panic (secp256k1-recover? message signature))) signer)
)

(define-private (generate-message-hash
                  (channel-id uint)
                  (balance-1 uint)
                  (balance-2 uint)
                  (nonce uint))
  (sha256 (concat 
    (unwrap-panic (to-consensus-buff? channel-id))
    (concat
      (unwrap-panic (to-consensus-buff? balance-1))
      (concat
        (unwrap-panic (to-consensus-buff? balance-2))
        (unwrap-panic (to-consensus-buff? nonce))
      )
    )
  ))
)

;; Public functions
(define-public (open-channel (channel-id uint) (participant-2 principal) (initial-balance-1 uint) (initial-balance-2 uint))
  (let
    ((caller tx-sender))
    
    ;; Check if channel already exists
    (asserts! (is-none (map-get? channels {channel-id: channel-id})) ERR_CHANNEL_ALREADY_OPEN)
    
    ;; Check if caller has sufficient STX
    (asserts! (>= (stx-get-balance caller) initial-balance-1) ERR_INSUFFICIENT_BALANCE)
    
    ;; Transfer initial balances to contract
    (try! (stx-transfer? initial-balance-1 caller (as-contract tx-sender)))
    
    ;; Initialize channel
    (map-set channels
      {channel-id: channel-id}
      {
        participant-1: caller,
        participant-2: participant-2,
        balance-1: initial-balance-1,
        balance-2: u0, ;; Participant 2 will need to deposit separately
        nonce: u0,
        state: "OPEN",
        challenge-height: u0
      }
    )
    
    (ok true)
  )
)

(define-public (join-channel (channel-id uint))
  (let
    ((caller tx-sender)
     (channel (unwrap! (map-get? channels {channel-id: channel-id}) ERR_CHANNEL_NOT_OPEN)))
    
    ;; Verify caller is participant 2
    (asserts! (is-eq caller (get participant-2 channel)) ERR_UNAUTHORIZED)
    
    ;; Verify channel is in expected state
    (asserts! (is-eq (get state channel) "OPEN") ERR_INVALID_STATE)
    
    ;; Check if participant 2 has sufficient STX
    (asserts! (>= (stx-get-balance caller) (get balance-2 channel)) ERR_INSUFFICIENT_BALANCE)
    
    ;; Transfer initial balance from participant 2
    (try! (stx-transfer? (get balance-2 channel) caller (as-contract tx-sender)))
    
    ;; Update channel state
    (map-set channels
      {channel-id: channel-id}
      (merge channel {state: "ACTIVE"})
    )
    
    (ok true)
  )
)

(define-public (update-channel-state
                (channel-id uint)
                (new-balance-1 uint)
                (new-balance-2 uint)
                (new-nonce uint)
                (signature-1 (buff 65))
                (signature-2 (buff 65)))
  (let
    ((channel (unwrap! (map-get? channels {channel-id: channel-id}) ERR_CHANNEL_NOT_OPEN))
     (participant-1 (get participant-1 channel))
     (participant-2 (get participant-2 channel))
     (current-nonce (get nonce channel))
     (message-hash (generate-message-hash channel-id new-balance-1 new-balance-2 new-nonce)))
    
    ;; Verify channel is active
    (asserts! (is-eq (get state channel) "ACTIVE") ERR_INVALID_STATE)
    
    ;; Verify nonce is higher than current
    (asserts! (> new-nonce current-nonce) ERR_INVALID_STATE)
    
    ;; Verify total balance hasn't changed
    (asserts! (is-eq (+ new-balance-1 new-balance-2) (+ (get balance-1 channel) (get balance-2 channel))) ERR_INVALID_STATE)
    
    ;; Verify both signatures
    (asserts! (verify-signature message-hash signature-1 participant-1) ERR_INVALID_SIGNATURE)
    (asserts! (verify-signature message-hash signature-2 participant-2) ERR_INVALID_SIGNATURE)
    
    ;; Update channel state
    (map-set channels
      {channel-id: channel-id}
      (merge channel 
        {
          balance-1: new-balance-1,
          balance-2: new-balance-2,
          nonce: new-nonce
        }
      )
    )
    
    (ok true)
  )
)

(define-public (initiate-close (channel-id uint))
  (let
    ((caller tx-sender)
     (channel (unwrap! (map-get? channels {channel-id: channel-id}) ERR_CHANNEL_NOT_OPEN))
     (current-block-height block-height))
    
    ;; Verify caller is one of the participants
    (asserts! (or (is-eq caller (get participant-1 channel)) (is-eq caller (get participant-2 channel))) ERR_UNAUTHORIZED)
    
    ;; Verify channel is active
    (asserts! (is-eq (get state channel) "ACTIVE") ERR_INVALID_STATE)
    
    ;; Set challenge period
    (map-set channels
      {channel-id: channel-id}
      (merge channel 
        {
          state: "CLOSING",
          challenge-height: (+ current-block-height CHALLENGE_PERIOD_BLOCKS)
        }
      )
    )
    
    (ok true)
  )
)

(define-public (close-channel (channel-id uint))
  (let
    ((channel (unwrap! (map-get? channels {channel-id: channel-id}) ERR_CHANNEL_NOT_OPEN))
     (participant-1 (get participant-1 channel))
     (participant-2 (get participant-2 channel))
     (balance-1 (get balance-1 channel))
     (balance-2 (get balance-2 channel))
     (current-block-height block-height))
    
    ;; Verify challenge period has passed
    (asserts! (and (is-eq (get state channel) "CLOSING") (>= current-block-height (get challenge-height channel))) ERR_CHALLENGE_PERIOD_ACTIVE)
    
    ;; Transfer balances back to participants
    (try! (as-contract (stx-transfer? balance-1 tx-sender participant-1)))
    (try! (as-contract (stx-transfer? balance-2 tx-sender participant-2)))
    
    ;; Delete channel
    (map-delete channels {channel-id: channel-id})
    
    (ok true)
  )
)
