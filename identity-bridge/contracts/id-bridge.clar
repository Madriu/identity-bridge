;; Identity Bridge - Cross-Platform Identity Linking Smart Contract
;; Self-sovereign identity verification on Stacks blockchain

;; Contract constants
(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-not-found (err u101))
(define-constant err-already-exists (err u102))
(define-constant err-unauthorized (err u103))
(define-constant err-invalid-signature (err u104))
(define-constant err-expired (err u105))

;; Data structures
(define-map identities
  principal
  {
    did: (string-ascii 64),
    created-at: uint,
    updated-at: uint,
    is-active: bool,
    reputation-score: uint
  }
)

(define-map identity-claims
  { identity: principal, claim-type: (string-ascii 32) }
  {
    claim-data: (string-ascii 256),
    verifier: principal,
    verified-at: uint,
    expires-at: uint,
    is-verified: bool
  }
)

(define-map cross-platform-links
  { identity: principal, platform: (string-ascii 32) }
  {
    platform-id: (string-ascii 64),
    linked-at: uint,
    verification-hash: (buff 32),
    is-active: bool
  }
)

(define-map verifiers
  principal
  {
    name: (string-ascii 64),
    is-authorized: bool,
    added-at: uint,
    verification-count: uint
  }
)

(define-map identity-revocations
  principal
  {
    revoked-at: uint,
    reason: (string-ascii 128),
    revoked-by: principal
  }
)

;; Data variables
(define-data-var total-identities uint u0)
(define-data-var total-verifications uint u0)

;; Private functions
(define-private (generate-did (user principal))
  (let ((user-bytes (unwrap-panic (to-consensus-buff? user)))
        (user-hash (sha256 user-bytes)))
    (concat "did:stx:" 
      (unwrap-panic (as-max-len?
        (int-to-ascii (+ block-height (len user-bytes))) u48)))
  )
)

(define-private (is-verifier (user principal))
  (match (map-get? verifiers user)
    verifier (get is-authorized verifier)
    false
  )
)

(define-private (update-verifier-count (verifier principal))
  (match (map-get? verifiers verifier)
    current-verifier
    (map-set verifiers verifier
      (merge current-verifier { verification-count: (+ (get verification-count current-verifier) u1) })
    )
    false
  )
)

;; Public functions

;; Create a new identity
(define-public (create-identity)
  (let ((caller tx-sender)
        (did (generate-did caller)))
    (asserts! (is-none (map-get? identities caller)) err-already-exists)
    (map-set identities caller {
      did: did,
      created-at: block-height,
      updated-at: block-height,
      is-active: true,
      reputation-score: u100
    })
    (var-set total-identities (+ (var-get total-identities) u1))
    (ok did)
  )
)

;; Add or update an identity claim
(define-public (add-claim (claim-type (string-ascii 32)) 
                         (claim-data (string-ascii 256)) 
                         (expires-at uint))
  (let ((caller tx-sender))
    (asserts! (is-some (map-get? identities caller)) err-not-found)
    (map-set identity-claims 
      { identity: caller, claim-type: claim-type }
      {
        claim-data: claim-data,
        verifier: caller,
        verified-at: block-height,
        expires-at: expires-at,
        is-verified: false
      }
    )
    (ok true)
  )
)

;; Verify a claim (only authorized verifiers)
(define-public (verify-claim (identity principal) (claim-type (string-ascii 32)))
  (let ((verifier tx-sender))
    (asserts! (is-verifier verifier) err-unauthorized)
    (match (map-get? identity-claims { identity: identity, claim-type: claim-type })
      claim
      (begin
        (map-set identity-claims 
          { identity: identity, claim-type: claim-type }
          (merge claim {
            verifier: verifier,
            verified-at: block-height,
            is-verified: true
          })
        )
        (update-verifier-count verifier)
        (var-set total-verifications (+ (var-get total-verifications) u1))
        (ok true)
      )
      err-not-found
    )
  )
)

;; Link identity to external platform
(define-public (link-platform (platform (string-ascii 32)) 
                              (platform-id (string-ascii 64)) 
                              (verification-hash (buff 32)))
  (let ((caller tx-sender))
    (asserts! (is-some (map-get? identities caller)) err-not-found)
    (map-set cross-platform-links
      { identity: caller, platform: platform }
      {
        platform-id: platform-id,
        linked-at: block-height,
        verification-hash: verification-hash,
        is-active: true
      }
    )
    (ok true)
  )
)

;; Unlink platform
(define-public (unlink-platform (platform (string-ascii 32)))
  (let ((caller tx-sender))
    (match (map-get? cross-platform-links { identity: caller, platform: platform })
      link
      (begin
        (map-set cross-platform-links
          { identity: caller, platform: platform }
          (merge link { is-active: false })
        )
        (ok true)
      )
      err-not-found
    )
  )
)

;; Add authorized verifier (contract owner only)
(define-public (add-verifier (verifier principal) (name (string-ascii 64)))
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (map-set verifiers verifier {
      name: name,
      is-authorized: true,
      added-at: block-height,
      verification-count: u0
    })
    (ok true)
  )
)

;; Remove verifier authorization (contract owner only)
(define-public (revoke-verifier (verifier principal))
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (match (map-get? verifiers verifier)
      current-verifier
      (begin
        (map-set verifiers verifier
          (merge current-verifier { is-authorized: false })
        )
        (ok true)
      )
      err-not-found
    )
  )
)

;; Revoke identity (emergency function)
(define-public (revoke-identity (identity principal) (reason (string-ascii 128)))
  (let ((caller tx-sender))
    (asserts! (or (is-eq caller contract-owner) 
                  (is-eq caller identity)) err-unauthorized)
    (match (map-get? identities identity)
      current-identity
      (begin
        (map-set identities identity
          (merge current-identity { is-active: false })
        )
        (map-set identity-revocations identity {
          revoked-at: block-height,
          reason: reason,
          revoked-by: caller
        })
        (ok true)
      )
      err-not-found
    )
  )
)

;; Update reputation score (verifiers only)
(define-public (update-reputation (identity principal) (new-score uint))
  (let ((caller tx-sender))
    (asserts! (is-verifier caller) err-unauthorized)
    (match (map-get? identities identity)
      current-identity
      (begin
        (map-set identities identity
          (merge current-identity { 
            reputation-score: new-score,
            updated-at: block-height
          })
        )
        (ok true)
      )
      err-not-found
    )
  )
)

;; Read-only functions

;; Get identity information
(define-read-only (get-identity (user principal))
  (map-get? identities user)
)

;; Get claim information
(define-read-only (get-claim (identity principal) (claim-type (string-ascii 32)))
  (map-get? identity-claims { identity: identity, claim-type: claim-type })
)

;; Get platform link
(define-read-only (get-platform-link (identity principal) (platform (string-ascii 32)))
  (map-get? cross-platform-links { identity: identity, platform: platform })
)

;; Get verifier information
(define-read-only (get-verifier (verifier principal))
  (map-get? verifiers verifier)
)

;; Check if claim is valid (not expired and verified)
(define-read-only (is-claim-valid (identity principal) (claim-type (string-ascii 32)))
  (match (map-get? identity-claims { identity: identity, claim-type: claim-type })
    claim
    (and (get is-verified claim)
         (> (get expires-at claim) block-height))
    false
  )
)

;; Get contract statistics
(define-read-only (get-stats)
  {
    total-identities: (var-get total-identities),
    total-verifications: (var-get total-verifications),
    contract-owner: contract-owner
  }
)

;; Check if identity is active and not revoked
(define-read-only (is-identity-active (identity principal))
  (match (map-get? identities identity)
    id-data (get is-active id-data)
    false
  )
)

;; Get identity reputation score
(define-read-only (get-reputation (identity principal))
  (match (map-get? identities identity)
    id-data (some (get reputation-score id-data))
    none
  )
)