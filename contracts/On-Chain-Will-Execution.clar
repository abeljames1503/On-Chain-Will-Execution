(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_UNAUTHORIZED (err u100))
(define-constant ERR_WILL_NOT_FOUND (err u101))
(define-constant ERR_WILL_ALREADY_EXISTS (err u102))
(define-constant ERR_INVALID_BENEFICIARY (err u103))
(define-constant ERR_WILL_ALREADY_EXECUTED (err u104))
(define-constant ERR_INSUFFICIENT_CONFIRMATIONS (err u105))
(define-constant ERR_ALREADY_CONFIRMED (err u106))
(define-constant ERR_INVALID_EXECUTOR (err u107))
(define-constant ERR_WILL_NOT_READY (err u108))
(define-constant ERR_TRANSFER_FAILED (err u109))

(define-map wills
  { testator: principal }
  {
    beneficiaries: (list 10 { recipient: principal, amount: uint }),
    executors: (list 5 principal),
    required-confirmations: uint,
    is-executed: bool,
    total-amount: uint,
    created-at: uint
  }
)

(define-map death-confirmations
  { testator: principal, executor: principal }
  { confirmed: bool, confirmed-at: uint }
)

(define-map executor-confirmations
  { testator: principal }
  { count: uint }
)

(define-data-var total-wills uint u0)

(define-public (create-will 
  (beneficiaries (list 10 { recipient: principal, amount: uint }))
  (executors (list 5 principal))
  (required-confirmations uint))
  (let (
    (testator tx-sender)
    (total-amount (fold + (map get-amount beneficiaries) u0))
  )
    (asserts! (is-none (map-get? wills { testator: testator })) ERR_WILL_ALREADY_EXISTS)
    (asserts! (> (len beneficiaries) u0) ERR_INVALID_BENEFICIARY)
    (asserts! (> (len executors) u0) ERR_INVALID_EXECUTOR)
    (asserts! (<= required-confirmations (len executors)) ERR_INVALID_EXECUTOR)
    (asserts! (> required-confirmations u0) ERR_INVALID_EXECUTOR)
    
    (map-set wills
      { testator: testator }
      {
        beneficiaries: beneficiaries,
        executors: executors,
        required-confirmations: required-confirmations,
        is-executed: false,
        total-amount: total-amount,
        created-at: stacks-block-height
      }
    )
    
    (map-set executor-confirmations
      { testator: testator }
      { count: u0 }
    )
    
    (var-set total-wills (+ (var-get total-wills) u1))
    (ok true)
  )
)

(define-public (fund-will (testator principal))
  (let (
    (will-data (unwrap! (map-get? wills { testator: testator }) ERR_WILL_NOT_FOUND))
    (amount (get total-amount will-data))
  )
    (asserts! (is-eq tx-sender testator) ERR_UNAUTHORIZED)
    (asserts! (not (get is-executed will-data)) ERR_WILL_ALREADY_EXECUTED)
    
    (try! (stx-transfer? amount tx-sender (as-contract tx-sender)))
    (ok true)
  )
)

(define-public (confirm-death (testator principal))
  (let (
    (will-data (unwrap! (map-get? wills { testator: testator }) ERR_WILL_NOT_FOUND))
    (executor tx-sender)
    (executors (get executors will-data))
    (existing-confirmation (map-get? death-confirmations { testator: testator, executor: executor }))
    (current-confirmations (default-to { count: u0 } (map-get? executor-confirmations { testator: testator })))
  )
    (asserts! (is-some (index-of executors executor)) ERR_INVALID_EXECUTOR)
    (asserts! (is-none existing-confirmation) ERR_ALREADY_CONFIRMED)
    (asserts! (not (get is-executed will-data)) ERR_WILL_ALREADY_EXECUTED)
    
    (map-set death-confirmations
      { testator: testator, executor: executor }
      { confirmed: true, confirmed-at: stacks-block-height }
    )
    
    (map-set executor-confirmations
      { testator: testator }
      { count: (+ (get count current-confirmations) u1) }
    )
    
    (ok true)
  )
)

(define-public (execute-will (testator principal))
  (let (
    (will-data (unwrap! (map-get? wills { testator: testator }) ERR_WILL_NOT_FOUND))
    (confirmations (default-to { count: u0 } (map-get? executor-confirmations { testator: testator })))
    (required-confirmations (get required-confirmations will-data))
    (beneficiaries (get beneficiaries will-data))
  )
    (asserts! (not (get is-executed will-data)) ERR_WILL_ALREADY_EXECUTED)
    (asserts! (>= (get count confirmations) required-confirmations) ERR_INSUFFICIENT_CONFIRMATIONS)
    
    (try! (distribute-inheritance testator beneficiaries))
    
    (map-set wills
      { testator: testator }
      (merge will-data { is-executed: true })
    )
    
    (ok true)
  )
)

(define-private (distribute-inheritance (testator principal) (beneficiaries (list 10 { recipient: principal, amount: uint })))
  (fold check-transfer-result 
    (map transfer-to-beneficiary (list testator) beneficiaries) 
    (ok true)
  )
)

(define-private (transfer-to-beneficiary (testator principal) (beneficiary { recipient: principal, amount: uint }))
  (as-contract (stx-transfer? (get amount beneficiary) tx-sender (get recipient beneficiary)))
)

(define-private (check-transfer-result (transfer-result (response bool uint)) (acc (response bool uint)))
  (match acc
    success (match transfer-result
      ok-val (ok true)
      err-val (err err-val))
    err-val (err err-val))
)

(define-private (get-amount (beneficiary { recipient: principal, amount: uint }))
  (get amount beneficiary)
)

(define-read-only (get-will (testator principal))
  (map-get? wills { testator: testator })
)

(define-read-only (get-confirmation-count (testator principal))
  (default-to { count: u0 } (map-get? executor-confirmations { testator: testator }))
)

(define-read-only (get-executor-confirmation (testator principal) (executor principal))
  (map-get? death-confirmations { testator: testator, executor: executor })
)

(define-read-only (is-will-ready-for-execution (testator principal))
  (match (map-get? wills { testator: testator })
    will-data (let (
      (confirmations (get count (get-confirmation-count testator)))
      (required (get required-confirmations will-data))
      (executed (get is-executed will-data))
    )
      (and (>= confirmations required) (not executed))
    )
    false
  )
)

(define-read-only (get-contract-balance)
  (stx-get-balance (as-contract tx-sender))
)

(define-read-only (get-total-wills)
  (var-get total-wills)
)

(define-public (revoke-will)
  (let (
    (testator tx-sender)
    (will-data (unwrap! (map-get? wills { testator: testator }) ERR_WILL_NOT_FOUND))
    (total-amount (get total-amount will-data))
  )
    (asserts! (not (get is-executed will-data)) ERR_WILL_ALREADY_EXECUTED)
    
    (map-delete wills { testator: testator })
    (map-delete executor-confirmations { testator: testator })
    
    (as-contract (stx-transfer? total-amount tx-sender testator))
  )
)

(define-public (update-will-executors (new-executors (list 5 principal)) (new-required-confirmations uint))
  (let (
    (testator tx-sender)
    (will-data (unwrap! (map-get? wills { testator: testator }) ERR_WILL_NOT_FOUND))
  )
    (asserts! (not (get is-executed will-data)) ERR_WILL_ALREADY_EXECUTED)
    (asserts! (> (len new-executors) u0) ERR_INVALID_EXECUTOR)
    (asserts! (<= new-required-confirmations (len new-executors)) ERR_INVALID_EXECUTOR)
    (asserts! (> new-required-confirmations u0) ERR_INVALID_EXECUTOR)
    
    (map-set wills
      { testator: testator }
      (merge will-data {
        executors: new-executors,
        required-confirmations: new-required-confirmations
      })
    )
    
    (map-set executor-confirmations
      { testator: testator }
      { count: u0 }
    )
    
    (ok true)
  )
)
