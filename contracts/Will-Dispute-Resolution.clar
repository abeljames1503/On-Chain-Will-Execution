(define-constant ERR_WILL_NOT_FOUND (err u101))
(define-constant ERR_UNAUTHORIZED (err u100))
(define-constant ERR_DISPUTE_EXISTS (err u150))
(define-constant ERR_DISPUTE_NOT_FOUND (err u151))
(define-constant ERR_ALREADY_VOTED (err u152))
(define-constant ERR_DISPUTE_RESOLVED (err u153))
(define-constant ERR_INVALID_BENEFICIARY (err u154))
(define-constant ERR_DISPUTE_EXPIRED (err u155))

(define-constant DISPUTE_PERIOD u288)
(define-constant DISPUTE_THRESHOLD u51)

(define-map wills
  { testator: principal }
  {
    beneficiaries: (list 10 { recipient: principal, amount: uint }),
    total-amount: uint,
    is-executed: bool
  }
)

(define-map will-disputes
  { testator: principal }
  {
    initiated-at: uint,
    expires-at: uint,
    total-weight: uint,
    dispute-weight: uint,
    is-resolved: bool,
    resolution: (string-utf8 200)
  }
)

(define-map beneficiary-votes
  { testator: principal, beneficiary: principal }
  { voted-dispute: bool, voted-at: uint, vote-weight: uint }
)

(define-public (raise-dispute (testator principal) (reason (string-utf8 200)))
  (let (
    (will-data (unwrap! (map-get? wills { testator: testator }) ERR_WILL_NOT_FOUND))
    (beneficiary-weight (get-beneficiary-weight testator tx-sender (get beneficiaries will-data)))
  )
    (asserts! (> beneficiary-weight u0) ERR_INVALID_BENEFICIARY)
    (asserts! (is-none (map-get? will-disputes { testator: testator })) ERR_DISPUTE_EXISTS)
    (asserts! (not (get is-executed will-data)) ERR_WILL_NOT_FOUND)
    
    (map-set will-disputes { testator: testator }
      {
        initiated-at: stacks-block-height,
        expires-at: (+ stacks-block-height DISPUTE_PERIOD),
        total-weight: (get total-amount will-data),
        dispute-weight: beneficiary-weight,
        is-resolved: false,
        resolution: reason
      })
    
    (map-set beneficiary-votes { testator: testator, beneficiary: tx-sender }
      { voted-dispute: true, voted-at: stacks-block-height, vote-weight: beneficiary-weight })
    (ok true)))

(define-public (vote-dispute (testator principal) (support-dispute bool))
  (let (
    (will-data (unwrap! (map-get? wills { testator: testator }) ERR_WILL_NOT_FOUND))
    (dispute-data (unwrap! (map-get? will-disputes { testator: testator }) ERR_DISPUTE_NOT_FOUND))
    (beneficiary-weight (get-beneficiary-weight testator tx-sender (get beneficiaries will-data)))
  )
    (asserts! (> beneficiary-weight u0) ERR_INVALID_BENEFICIARY)
    (asserts! (is-none (map-get? beneficiary-votes { testator: testator, beneficiary: tx-sender })) ERR_ALREADY_VOTED)
    (asserts! (< stacks-block-height (get expires-at dispute-data)) ERR_DISPUTE_EXPIRED)
    
    (map-set beneficiary-votes { testator: testator, beneficiary: tx-sender }
      { voted-dispute: support-dispute, voted-at: stacks-block-height, vote-weight: beneficiary-weight })
    
    (if support-dispute
      (begin
        (map-set will-disputes { testator: testator }
          (merge dispute-data { dispute-weight: (+ (get dispute-weight dispute-data) beneficiary-weight) }))
        (ok true))
      (ok true))))

(define-public (resolve-dispute (testator principal) (resolution (string-utf8 200)))
  (let (
    (dispute-data (unwrap! (map-get? will-disputes { testator: testator }) ERR_DISPUTE_NOT_FOUND))
  )
    (asserts! (is-eq tx-sender testator) ERR_UNAUTHORIZED)
    (asserts! (not (get is-resolved dispute-data)) ERR_DISPUTE_RESOLVED)
    
    (map-set will-disputes { testator: testator }
      (merge dispute-data { is-resolved: true, resolution: resolution }))
    (ok true)))

(define-read-only (get-dispute-status (testator principal))
  (map-get? will-disputes { testator: testator }))

(define-read-only (is-dispute-blocking (testator principal))
  (match (map-get? will-disputes { testator: testator })
    dispute-data (and
      (not (get is-resolved dispute-data))
      (< stacks-block-height (get expires-at dispute-data))
      (>= (* (get dispute-weight dispute-data) u100) (* (get total-weight dispute-data) DISPUTE_THRESHOLD)))
    false))

(define-private (get-beneficiary-weight (testator principal) (beneficiary principal) (beneficiaries (list 10 { recipient: principal, amount: uint })))
  (get weight (fold check-beneficiary beneficiaries { target: beneficiary, weight: u0 })))

(define-private (check-beneficiary (entry { recipient: principal, amount: uint }) (acc { target: principal, weight: uint }))
  (if (is-eq (get recipient entry) (get target acc))
    { target: (get target acc), weight: (get amount entry) }
    acc))
