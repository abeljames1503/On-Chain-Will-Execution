
(define-constant ERR_WILL_NOT_FOUND (err u101))
(define-constant ERR_METADATA_NOT_FOUND (err u110))
(define-constant ERR_METADATA_TOO_LARGE (err u111))
(define-constant ERR_INVALID_METADATA (err u112))


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

(define-map executor-confirmations
  { testator: principal }
  { count: uint }
)

(define-map will-metadata
  { testator: principal }
  {
    encrypted-data: (string-utf8 500),
    digital-assets: (list 10 (string-utf8 100)),
    final-message: (string-utf8 300),
    access-instructions: (string-utf8 200),
    created-at: uint,
    last-updated: uint
  }
)


(define-public (set-will-metadata
  (encrypted-data (string-utf8 500))
  (digital-assets (list 10 (string-utf8 100)))
  (final-message (string-utf8 300))
  (access-instructions (string-utf8 200)))
  (let (
    (testator tx-sender)
    (will-exists (is-some (map-get? wills { testator: testator })))
  )
    (asserts! will-exists ERR_WILL_NOT_FOUND)
    (asserts! (> (len encrypted-data) u0) ERR_INVALID_METADATA)
    
    (map-set will-metadata
      { testator: testator }
      {
        encrypted-data: encrypted-data,
        digital-assets: digital-assets,
        final-message: final-message,
        access-instructions: access-instructions,
        created-at: stacks-block-height,
        last-updated: stacks-block-height
      }
    )
    (ok true)
  )
)


(define-public (update-will-metadata
  (encrypted-data (string-utf8 500))
  (digital-assets (list 10 (string-utf8 100)))
  (final-message (string-utf8 300))
  (access-instructions (string-utf8 200)))
  (let (
    (testator tx-sender)
    (will-exists (is-some (map-get? wills { testator: testator })))
    (metadata-exists (is-some (map-get? will-metadata { testator: testator })))
  )
    (asserts! will-exists ERR_WILL_NOT_FOUND)
    (asserts! metadata-exists ERR_METADATA_NOT_FOUND)
    
    (map-set will-metadata
      { testator: testator }
      {
        encrypted-data: encrypted-data,
        digital-assets: digital-assets,
        final-message: final-message,
        access-instructions: access-instructions,
        created-at: (get created-at (unwrap-panic (map-get? will-metadata { testator: testator }))),
        last-updated: stacks-block-height
      }
    )
    (ok true)
  )
)


(define-read-only (get-will-metadata (testator principal))
  (let (
    (confirmations (get count (default-to { count: u0 } (map-get? executor-confirmations { testator: testator }))))
    (will-data (map-get? wills { testator: testator }))
  )
    (match will-data
      will-info (if (>= confirmations (get required-confirmations will-info))
        (map-get? will-metadata { testator: testator })
        none)
      none
    )
  )
)


(define-read-only (get-metadata-preview (testator principal))
  (if (is-eq tx-sender testator)
    (match (map-get? will-metadata { testator: testator })
      metadata-data (some { final-message: (get final-message metadata-data) })
      none)
    none
  )
)
