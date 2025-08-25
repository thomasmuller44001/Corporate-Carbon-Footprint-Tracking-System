;; Corporate Carbon Emissions Tracker Contract
;; Handles emission source identification, measurement, and tracking

;; Constants
(define-constant CONTRACT-OWNER tx-sender)
(define-constant ERR-NOT-AUTHORIZED (err u100))
(define-constant ERR-INVALID-INPUT (err u101))
(define-constant ERR-SOURCE-NOT-FOUND (err u102))
(define-constant ERR-ALREADY-EXISTS (err u103))

;; Data Variables
(define-data-var next-source-id uint u1)
(define-data-var total-sources uint u0)

;; Data Maps
(define-map emission-sources
  { id: uint }
  {
    name: (string-ascii 100),
    category: (string-ascii 20),
    scope: uint,
    emission-factor: uint,
    unit: (string-ascii 20),
    is-active: bool,
    created-by: principal,
    created-at: uint
  }
)

(define-map monthly-emissions
  { source-id: uint, year: uint, month: uint }
  {
    activity-data: uint,
    calculated-emissions: uint,
    recorded-by: principal,
    recorded-at: uint
  }
)

(define-map source-totals
  { source-id: uint, year: uint }
  { total-emissions: uint }
)

;; Authorization check
(define-private (is-authorized (caller principal))
  (is-eq caller CONTRACT-OWNER)
)

;; Register new emission source
(define-public (register-emission-source
  (name (string-ascii 100))
  (category (string-ascii 20))
  (scope uint)
  (emission-factor uint)
  (unit (string-ascii 20))
)
  (let ((source-id (var-get next-source-id)))
    (asserts! (is-authorized tx-sender) ERR-NOT-AUTHORIZED)
    (asserts! (> (len name) u0) ERR-INVALID-INPUT)
    ;; Fixed HTML entities to proper Clarity comparison operators
    (asserts! (and (>= scope u1) (<= scope u3)) ERR-INVALID-INPUT)
    (asserts! (> emission-factor u0) ERR-INVALID-INPUT)

    (map-set emission-sources
      { id: source-id }
      {
        name: name,
        category: category,
        scope: scope,
        emission-factor: emission-factor,
        unit: unit,
        is-active: true,
        created-by: tx-sender,
        created-at: block-height
      }
    )

    (var-set next-source-id (+ source-id u1))
    (var-set total-sources (+ (var-get total-sources) u1))

    (ok source-id)
  )
)

;; Record monthly emissions
(define-public (record-monthly-emissions
  (source-id uint)
  (year uint)
  (month uint)
  (activity-data uint)
)
  (let (
    (source (unwrap! (map-get? emission-sources { id: source-id }) ERR-SOURCE-NOT-FOUND))
    (emission-factor (get emission-factor source))
    (calculated-emissions (* activity-data emission-factor))
  )
    (asserts! (is-authorized tx-sender) ERR-NOT-AUTHORIZED)
    (asserts! (get is-active source) ERR-INVALID-INPUT)
    ;; Fixed HTML entities to proper Clarity comparison operators
    (asserts! (and (>= month u1) (<= month u12)) ERR-INVALID-INPUT)
    (asserts! (> activity-data u0) ERR-INVALID-INPUT)

    ;; Check if record already exists
    (asserts! (is-none (map-get? monthly-emissions { source-id: source-id, year: year, month: month })) ERR-ALREADY-EXISTS)

    ;; Record monthly emissions
    (map-set monthly-emissions
      { source-id: source-id, year: year, month: month }
      {
        activity-data: activity-data,
        calculated-emissions: calculated-emissions,
        recorded-by: tx-sender,
        recorded-at: block-height
      }
    )

    ;; Update yearly totals
    (let ((current-total (default-to u0 (get total-emissions (map-get? source-totals { source-id: source-id, year: year })))))
      (map-set source-totals
        { source-id: source-id, year: year }
        { total-emissions: (+ current-total calculated-emissions) }
      )
    )

    (ok calculated-emissions)
  )
)

;; Update emission factor
(define-public (update-emission-factor (source-id uint) (new-factor uint))
  (let ((source (unwrap! (map-get? emission-sources { id: source-id }) ERR-SOURCE-NOT-FOUND)))
    (asserts! (is-authorized tx-sender) ERR-NOT-AUTHORIZED)
    (asserts! (> new-factor u0) ERR-INVALID-INPUT)

    (map-set emission-sources
      { id: source-id }
      (merge source { emission-factor: new-factor })
    )

    (ok true)
  )
)

;; Deactivate emission source
(define-public (deactivate-source (source-id uint))
  (let ((source (unwrap! (map-get? emission-sources { id: source-id }) ERR-SOURCE-NOT-FOUND)))
    (asserts! (is-authorized tx-sender) ERR-NOT-AUTHORIZED)

    (map-set emission-sources
      { id: source-id }
      (merge source { is-active: false })
    )

    (ok true)
  )
)

;; Read-only functions
(define-read-only (get-emission-source (source-id uint))
  (map-get? emission-sources { id: source-id })
)

(define-read-only (get-monthly-emissions (source-id uint) (year uint) (month uint))
  (map-get? monthly-emissions { source-id: source-id, year: year, month: month })
)

(define-read-only (get-source-yearly-total (source-id uint) (year uint))
  (map-get? source-totals { source-id: source-id, year: year })
)

(define-read-only (get-total-sources)
  (var-get total-sources)
)

(define-read-only (get-next-source-id)
  (var-get next-source-id)
)

;; Calculate total emissions for a year across all sources
(define-read-only (calculate-total-emissions (year uint))
  (let ((total-sources-count (var-get total-sources)))
    (fold calculate-source-total (list u1 u2 u3 u4 u5 u6 u7 u8 u9 u10) { year: year, total: u0 })
  )
)

(define-private (calculate-source-total (source-id uint) (acc { year: uint, total: uint }))
  (let (
    (year (get year acc))
    (current-total (get total acc))
    (source-total (default-to u0 (get total-emissions (map-get? source-totals { source-id: source-id, year: year }))))
  )
    { year: year, total: (+ current-total source-total) }
  )
)
