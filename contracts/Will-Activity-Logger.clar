(define-constant ERR_WILL_NOT_FOUND (err u101))
(define-constant ERR_UNAUTHORIZED (err u100))
(define-constant ERR_INVALID_ACTIVITY (err u120))
(define-constant ERR_INVALID_PAGINATION (err u121))

(define-constant ACTIVITY_WILL_CREATED u1)
(define-constant ACTIVITY_WILL_FUNDED u2)
(define-constant ACTIVITY_DEATH_CONFIRMED u3)
(define-constant ACTIVITY_WILL_EXECUTED u4)
(define-constant ACTIVITY_WILL_REVOKED u5)
(define-constant ACTIVITY_EXECUTORS_UPDATED u6)
(define-constant ACTIVITY_METADATA_SET u7)
(define-constant ACTIVITY_METADATA_UPDATED u8)

(define-map will-activities
  { testator: principal, activity-id: uint }
  {
    activity-type: uint,
    actor: principal,
    details: (string-utf8 200),
    timestamp: uint
  }
)

(define-map activity-counters
  { testator: principal }
  { total-activities: uint }
)

(define-public (log-activity
  (testator principal)
  (activity-type uint)
  (details (string-utf8 200)))
  (let (
    (current-counter (default-to { total-activities: u0 } (map-get? activity-counters { testator: testator })))
    (next-id (+ (get total-activities current-counter) u1))
  )
    (asserts! (and (>= activity-type u1) (<= activity-type u8)) ERR_INVALID_ACTIVITY)
    
    (map-set will-activities
      { testator: testator, activity-id: next-id }
      {
        activity-type: activity-type,
        actor: tx-sender,
        details: details,
        timestamp: stacks-block-height
      }
    )
    
    (map-set activity-counters
      { testator: testator }
      { total-activities: next-id }
    )
    
    (ok next-id)
  )
)

(define-read-only (get-activity-count (testator principal))
  (get total-activities (default-to { total-activities: u0 } (map-get? activity-counters { testator: testator })))
)

(define-read-only (get-activity (testator principal) (activity-id uint))
  (map-get? will-activities { testator: testator, activity-id: activity-id })
)

(define-read-only (get-activities-paginated (testator principal) (start uint) (limit uint))
  (let (
    (total-count (get-activity-count testator))
    (end (min (+ start limit) total-count))
    (valid-start (<= start total-count))
    (valid-limit (and (> limit u0) (<= limit u20)))
  )
    (asserts! valid-start (err ERR_INVALID_PAGINATION))
    (asserts! valid-limit (err ERR_INVALID_PAGINATION))
    
    (ok (map get-activity-with-id 
         (generate-range start end testator)))
  )
)

(define-read-only (get-recent-activities (testator principal))
  (get-activities-paginated testator (max (get-activity-count testator) u10) u10)
)

(define-private (generate-range (start uint) (end uint) (testator principal))
  (map create-activity-pair 
       (list start (+ start u1) (+ start u2) (+ start u3) (+ start u4)
             (+ start u5) (+ start u6) (+ start u7) (+ start u8) (+ start u9)))
)

(define-private (create-activity-pair (id uint))
  id
)

(define-private (get-activity-with-id (activity-id uint))
  { id: activity-id, activity: (get-activity tx-sender activity-id) }
)

(define-private (min (a uint) (b uint))
  (if (<= a b) a b)
)

(define-private (max (a uint) (b uint))
  (if (>= a b) a b)
)
