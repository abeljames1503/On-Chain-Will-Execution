(define-constant ERR_WILL_NOT_FOUND (err u101))
(define-constant ERR_UNAUTHORIZED (err u100))
(define-constant ERR_TIMELOCK_EXISTS (err u140))
(define-constant ERR_TIMELOCK_NOT_FOUND (err u141))
(define-constant ERR_TIMELOCK_ACTIVE (err u142))
(define-constant ERR_INVALID_DURATION (err u143))
(define-constant ERR_TOO_EARLY (err u144))

(define-constant MIN_LOCK_DURATION u144)
(define-constant MAX_LOCK_DURATION u52560)
(define-constant DEFAULT_CHECKIN_PERIOD u4320)

(define-map will-timelocks
  { testator: principal }
  {
    execution-allowed-at: uint,
    last-checkin: uint,
    checkin-period: uint,
    is-locked: bool,
    lock-reason: (string-utf8 100)
  }
)

(define-map scheduled-executions
  { testator: principal }
  {
    scheduled-height: uint,
    can-execute-early: bool,
    scheduled-by: principal,
    scheduled-at: uint
  }
)

(define-public (set-timelock (lock-duration uint) (checkin-period uint) (reason (string-utf8 100)))
  (let ((testator tx-sender))
    (asserts! (is-none (map-get? will-timelocks { testator: testator })) ERR_TIMELOCK_EXISTS)
    (asserts! (>= lock-duration MIN_LOCK_DURATION) ERR_INVALID_DURATION)
    (asserts! (<= lock-duration MAX_LOCK_DURATION) ERR_INVALID_DURATION)
    
    (map-set will-timelocks { testator: testator }
      {
        execution-allowed-at: (+ stacks-block-height lock-duration),
        last-checkin: stacks-block-height,
        checkin-period: checkin-period,
        is-locked: true,
        lock-reason: reason
      })
    (ok true)))

(define-public (checkin)
  (let (
    (testator tx-sender)
    (timelock-data (unwrap! (map-get? will-timelocks { testator: testator }) ERR_TIMELOCK_NOT_FOUND))
  )
    (map-set will-timelocks { testator: testator }
      (merge timelock-data { last-checkin: stacks-block-height }))
    (ok true)))

(define-public (schedule-execution (testator principal) (target-height uint) (allow-early bool))
  (begin
    (asserts! (is-eq tx-sender testator) ERR_UNAUTHORIZED)
    (asserts! (> target-height stacks-block-height) ERR_INVALID_DURATION)
    
    (map-set scheduled-executions { testator: testator }
      {
        scheduled-height: target-height,
        can-execute-early: allow-early,
        scheduled-by: tx-sender,
        scheduled-at: stacks-block-height
      })
    (ok true)))

(define-public (unlock-will)
  (let (
    (testator tx-sender)
    (timelock-data (unwrap! (map-get? will-timelocks { testator: testator }) ERR_TIMELOCK_NOT_FOUND))
  )
    (asserts! (>= stacks-block-height (get execution-allowed-at timelock-data)) ERR_TOO_EARLY)
    (map-set will-timelocks { testator: testator }
      (merge timelock-data { is-locked: false }))
    (ok true)))

(define-read-only (get-timelock-status (testator principal))
  (map-get? will-timelocks { testator: testator }))

(define-read-only (is-execution-allowed (testator principal))
  (match (map-get? will-timelocks { testator: testator })
    timelock-data (and
      (not (get is-locked timelock-data))
      (>= stacks-block-height (get execution-allowed-at timelock-data)))
    true))

(define-read-only (is-checkin-expired (testator principal))
  (match (map-get? will-timelocks { testator: testator })
    timelock-data (> (- stacks-block-height (get last-checkin timelock-data)) (get checkin-period timelock-data))
    false))

(define-read-only (get-scheduled-execution (testator principal))
  (map-get? scheduled-executions { testator: testator }))

(define-read-only (can-execute-scheduled (testator principal))
  (match (map-get? scheduled-executions { testator: testator })
    schedule-data (or
      (>= stacks-block-height (get scheduled-height schedule-data))
      (get can-execute-early schedule-data))
    false))