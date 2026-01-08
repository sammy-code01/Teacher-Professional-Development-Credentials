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

;; Data Maps for Enhanced Functionality
(define-map credential-endorsements
  { credential-id: uint, endorser: principal }
  { 
    endorsement-date: uint,
    endorsement-note: (string-ascii 200)
  }
)

(define-map credential-endorsement-count uint uint)

(define-map teacher-specializations
  { teacher: principal, specialization: (string-ascii 100) }
  { 
    verified: bool,
    verification-date: uint
  }
)

(define-map credential-metadata
  uint
  {
    hours-completed: uint,
    institution: (string-ascii 100),
    course-name: (string-ascii 200)
  }
)

;; #[allow(unchecked_data)]
(define-public (endorse-credential
  (credential-id uint)
  (endorsement-note (string-ascii 200)))
  (let
    (
      (credential (unwrap! (map-get? credentials credential-id) err-not-found))
      (endorsement-key { credential-id: credential-id, endorser: tx-sender })
    )
    (asserts! (get valid credential) err-unauthorized)
    (map-set credential-endorsements endorsement-key
      {
        endorsement-date: burn-block-height,
        endorsement-note: endorsement-note
      }
    )
    (map-set credential-endorsement-count credential-id
      (+ (default-to u0 (map-get? credential-endorsement-count credential-id)) u1)
    )
    (ok true)
  )
)

;; #[allow(unchecked_data)]
(define-public (add-credential-metadata
  (credential-id uint)
  (hours-completed uint)
  (institution (string-ascii 100))
  (course-name (string-ascii 200)))
  (let
    (
      (credential (unwrap! (map-get? credentials credential-id) err-not-found))
    )
    (asserts! (is-eq tx-sender (get issuing-body credential)) err-unauthorized)
    (map-set credential-metadata credential-id
      {
        hours-completed: hours-completed,
        institution: institution,
        course-name: course-name
      }
    )
    (ok true)
  )
)

;; #[allow(unchecked_data)]
(define-public (verify-teacher-specialization
  (teacher principal)
  (specialization (string-ascii 100)))
  (begin
    (asserts! (is-authorized-issuer tx-sender) err-unauthorized)
    (map-set teacher-specializations
      { teacher: teacher, specialization: specialization }
      {
        verified: true,
        verification-date: burn-block-height
      }
    )
    (ok true)
  )
)

;; #[allow(unchecked_data)]
(define-public (revoke-specialization
  (teacher principal)
  (specialization (string-ascii 100)))
  (let
    (
      (spec-data (unwrap! (map-get? teacher-specializations 
        { teacher: teacher, specialization: specialization }) err-not-found))
    )
    (asserts! (is-authorized-issuer tx-sender) err-unauthorized)
    (map-set teacher-specializations
      { teacher: teacher, specialization: specialization }
      (merge spec-data { verified: false })
    )
    (ok true)
  )
)

;; Read-only functions for new features
(define-read-only (get-credential-endorsement-count (credential-id uint))
  (default-to u0 (map-get? credential-endorsement-count credential-id))
)

(define-read-only (get-credential-endorsement 
  (credential-id uint) 
  (endorser principal))
  (map-get? credential-endorsements 
    { credential-id: credential-id, endorser: endorser })
)

(define-read-only (get-credential-metadata (credential-id uint))
  (map-get? credential-metadata credential-id)
)

(define-read-only (get-teacher-specialization
  (teacher principal)
  (specialization (string-ascii 100)))
  (map-get? teacher-specializations 
    { teacher: teacher, specialization: specialization })
)

(define-read-only (is-specialization-verified
  (teacher principal)
  (specialization (string-ascii 100)))
  (match (map-get? teacher-specializations 
    { teacher: teacher, specialization: specialization })
    spec-data (get verified spec-data)
    false
  )
)

;; Batch operations
;; #[allow(unchecked_data)]
(define-public (batch-authorize-issuers (issuer-list (list 10 principal)))
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-unauthorized)
    (ok (map authorize-issuer-internal issuer-list))
  )
)

(define-private (authorize-issuer-internal (issuer principal))
  (begin
    (map-set authorized-issuers issuer true)
    true
  )
)

;; #[allow(unchecked_data)]
(define-public (batch-revoke-credentials (credential-ids (list 10 uint)))
  (ok (map revoke-credential-internal credential-ids))
)

(define-private (revoke-credential-internal (credential-id uint))
  (match (map-get? credentials credential-id)
    credential 
      (if (is-eq tx-sender (get issuing-body credential))
        (begin
          (map-set credentials credential-id (merge credential { valid: false }))
          true
        )
        false
      )
    false
  )
)