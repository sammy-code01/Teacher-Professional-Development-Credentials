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