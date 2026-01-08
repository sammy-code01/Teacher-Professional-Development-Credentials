;; Teacher Professional Development Credentials Contract
;; Blockchain-based teacher certification and credential system

;; Constants
(define-constant contract-owner tx-sender)
(define-constant err-not-found (err u100))
(define-constant err-unauthorized (err u101))
(define-constant err-already-issued (err u102))

;; Data Variables
(define-data-var credential-nonce uint u0)

;; Data Maps
(define-map credentials
  uint
  {
    teacher: principal,
    credential-type: (string-ascii 100),
    issuing-body: principal,
    issue-date: uint,
    expiry-date: uint,
    valid: bool
  }
)

(define-map teacher-credentials
  { teacher: principal, credential-type: (string-ascii 100) }
  uint
)

(define-map authorized-issuers principal bool)

(define-map teacher-credential-count principal uint)

;; Read-only functions
(define-read-only (get-credential (credential-id uint))
  (map-get? credentials credential-id)
)

(define-read-only (get-teacher-credential (teacher principal) (credential-type (string-ascii 100)))
  (match (map-get? teacher-credentials { teacher: teacher, credential-type: credential-type })
    credential-id (map-get? credentials credential-id)
    none
  )
)

(define-read-only (is-authorized-issuer (issuer principal))
  (default-to false (map-get? authorized-issuers issuer))
)

(define-read-only (get-teacher-credential-count (teacher principal))
  (default-to u0 (map-get? teacher-credential-count teacher))
)

(define-read-only (get-credential-nonce)
  (var-get credential-nonce)
)

;; Advanced Read-only Functions
(define-read-only (is-credential-valid (credential-id uint))
  (match (map-get? credentials credential-id)
    credential (and 
      (get valid credential)
      (> (get expiry-date credential) burn-block-height)
    )
    false
  )
)

(define-read-only (is-credential-expired (credential-id uint))
  (match (map-get? credentials credential-id)
    credential (<= (get expiry-date credential) burn-block-height)
    true
  )
)

(define-read-only (get-credential-issuer (credential-id uint))
  (match (map-get? credentials credential-id)
    credential (some (get issuing-body credential))
    none
  )
)

(define-read-only (get-credential-type (credential-id uint))
  (match (map-get? credentials credential-id)
    credential (some (get credential-type credential))
    none
  )
)

(define-read-only (get-credential-teacher (credential-id uint))
  (match (map-get? credentials credential-id)
    credential (some (get teacher credential))
    none
  )
)

(define-read-only (get-credential-issue-date (credential-id uint))
  (match (map-get? credentials credential-id)
    credential (some (get issue-date credential))
    none
  )
)

(define-read-only (get-credential-expiry-date (credential-id uint))
  (match (map-get? credentials credential-id)
    credential (some (get expiry-date credential))
    none
  )
)

;; Public functions
;; #[allow(unchecked_data)]
(define-public (authorize-issuer (issuer principal))
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-unauthorized)
    (map-set authorized-issuers issuer true)
    (ok true)
  )
)

;; #[allow(unchecked_data)]
(define-public (issue-credential 
  (teacher principal) 
  (credential-type (string-ascii 100))
  (expiry-date uint))
  (let
    (
      (credential-id (var-get credential-nonce))
      (existing (map-get? teacher-credentials { teacher: teacher, credential-type: credential-type }))
    )
    (asserts! (is-authorized-issuer tx-sender) err-unauthorized)
    (asserts! (is-none existing) err-already-issued)
    (map-set credentials credential-id
      {
        teacher: teacher,
        credential-type: credential-type,
        issuing-body: tx-sender,
        issue-date: burn-block-height,
        expiry-date: expiry-date,
        valid: true
      }
    )
    (map-set teacher-credentials 
      { teacher: teacher, credential-type: credential-type }
      credential-id
    )
    (map-set teacher-credential-count teacher 
      (+ (get-teacher-credential-count teacher) u1)
    )
    (var-set credential-nonce (+ credential-id u1))
    (ok credential-id)
  )
)

;; #[allow(unchecked_data)]
(define-public (revoke-credential (credential-id uint))
  (let
    (
      (credential (unwrap! (map-get? credentials credential-id) err-not-found))
    )
    (asserts! (is-eq tx-sender (get issuing-body credential)) err-unauthorized)
    (map-set credentials credential-id (merge credential { valid: false }))
    (ok true)
  )
)

;; #[allow(unchecked_data)]
(define-public (revoke-issuer (issuer principal))
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-unauthorized)
    (map-set authorized-issuers issuer false)
    (ok true)
  )
)

;; #[allow(unchecked_data)]
(define-public (renew-credential 
  (credential-id uint)
  (new-expiry-date uint))
  (let
    (
      (credential (unwrap! (map-get? credentials credential-id) err-not-found))
    )
    (asserts! (is-eq tx-sender (get issuing-body credential)) err-unauthorized)
    (map-set credentials credential-id 
      (merge credential { expiry-date: new-expiry-date, valid: true })
    )
    (ok true)
  )
)

;; #[allow(unchecked_data)]
(define-public (transfer-credential-ownership
  (credential-id uint)
  (new-issuer principal))
  (let
    (
      (credential (unwrap! (map-get? credentials credential-id) err-not-found))
    )
    (asserts! (is-eq tx-sender (get issuing-body credential)) err-unauthorized)
    (asserts! (is-authorized-issuer new-issuer) err-unauthorized)
    (map-set credentials credential-id 
      (merge credential { issuing-body: new-issuer })
    )
    (ok true)
  )
)