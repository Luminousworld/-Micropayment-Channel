
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