
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