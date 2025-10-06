(define-constant ERR_WILL_NOT_FOUND (err u101))
(define-constant ERR_UNAUTHORIZED (err u100))
(define-constant ERR_INVALID_GUARDIAN (err u130))
(define-constant ERR_RECOVERY_ACTIVE (err u131))
(define-constant ERR_RECOVERY_NOT_FOUND (err u132))
(define-constant ERR_ALREADY_APPROVED (err u133))
(define-constant ERR_RECOVERY_EXPIRED (err u134))
(define-constant ERR_INSUFFICIENT_APPROVALS (err u135))

(define-constant RECOVERY_PERIOD u144)
(define-constant MIN_GUARDIANS u2)
(define-constant MAX_GUARDIANS u5)

(define-map guardians
  { testator: principal }
  { guardian-list: (list 5 principal), required-approvals: uint }
)

(define-map recovery-requests
  { testator: principal }
  {
    new-address: principal,
    initiated-at: uint,
    expires-at: uint,
    approvals: uint,
    is-active: bool
  }
)

(define-map guardian-approvals
  { testator: principal, guardian: principal }
  { approved: bool, approved-at: uint }
)

(define-public (set-guardians (guardian-list (list 5 principal)) (required-approvals uint))
  (let ((testator tx-sender))
    (asserts! (>= (len guardian-list) MIN_GUARDIANS) ERR_INVALID_GUARDIAN)
    (asserts! (<= (len guardian-list) MAX_GUARDIANS) ERR_INVALID_GUARDIAN)
    (asserts! (<= required-approvals (len guardian-list)) ERR_INVALID_GUARDIAN)
    (asserts! (>= required-approvals MIN_GUARDIANS) ERR_INVALID_GUARDIAN)
    
    (map-set guardians { testator: testator }
      { guardian-list: guardian-list, required-approvals: required-approvals })
    (ok true)))

(define-public (initiate-recovery (testator principal) (new-address principal))
  (let (
    (guardian-data (unwrap! (map-get? guardians { testator: testator }) ERR_WILL_NOT_FOUND))
    (existing-recovery (map-get? recovery-requests { testator: testator }))
  )
    (asserts! (is-some (index-of (get guardian-list guardian-data) tx-sender)) ERR_UNAUTHORIZED)
    (asserts! (is-none existing-recovery) ERR_RECOVERY_ACTIVE)
    
    (map-set recovery-requests { testator: testator }
      {
        new-address: new-address,
        initiated-at: stacks-block-height,
        expires-at: (+ stacks-block-height RECOVERY_PERIOD),
        approvals: u1,
        is-active: true
      })
    
    (map-set guardian-approvals { testator: testator, guardian: tx-sender }
      { approved: true, approved-at: stacks-block-height })
    (ok true)))

(define-public (approve-recovery (testator principal))
  (let (
    (guardian-data (unwrap! (map-get? guardians { testator: testator }) ERR_WILL_NOT_FOUND))
    (recovery-data (unwrap! (map-get? recovery-requests { testator: testator }) ERR_RECOVERY_NOT_FOUND))
    (existing-approval (map-get? guardian-approvals { testator: testator, guardian: tx-sender }))
  )
    (asserts! (is-some (index-of (get guardian-list guardian-data) tx-sender)) ERR_UNAUTHORIZED)
    (asserts! (get is-active recovery-data) ERR_RECOVERY_NOT_FOUND)
    (asserts! (< stacks-block-height (get expires-at recovery-data)) ERR_RECOVERY_EXPIRED)
    (asserts! (is-none existing-approval) ERR_ALREADY_APPROVED)
    
    (map-set guardian-approvals { testator: testator, guardian: tx-sender }
      { approved: true, approved-at: stacks-block-height })
    
    (map-set recovery-requests { testator: testator }
      (merge recovery-data { approvals: (+ (get approvals recovery-data) u1) }))
    (ok true)))

(define-read-only (get-guardians (testator principal))
  (map-get? guardians { testator: testator }))

(define-read-only (get-recovery-status (testator principal))
  (map-get? recovery-requests { testator: testator }))

(define-read-only (can-complete-recovery (testator principal))
  (match (map-get? recovery-requests { testator: testator })
    recovery-data (match (map-get? guardians { testator: testator })
      guardian-data (and
        (get is-active recovery-data)
        (< stacks-block-height (get expires-at recovery-data))
        (>= (get approvals recovery-data) (get required-approvals guardian-data)))
      false)
    false))
