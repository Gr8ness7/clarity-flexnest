;; FlexNest Contract - Enhanced Version

;; Constants
(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-invalid-plan (err u101))
(define-constant err-already-subscribed (err u102))
(define-constant err-not-subscribed (err u103))
(define-constant err-insufficient-balance (err u104))
(define-constant err-contract-paused (err u105))
(define-constant err-invalid-payment (err u106))

;; Data vars
(define-data-var next-plan-id uint u1)
(define-data-var contract-paused bool false)

;; Data maps
(define-map subscription-plans
  uint
  {
    name: (string-ascii 64),
    price: uint,
    duration: uint,
    active: bool
  }
)

(define-map subscriptions
  principal
  {
    plan-id: uint,
    start-time: uint,
    end-time: uint,
    active: bool,
    auto-renew: bool
  }
)

;; Events
(define-data-var last-event-id uint u0)

(define-map events
  uint
  {
    event-type: (string-ascii 20),
    user: principal,
    data: (string-ascii 64),
    timestamp: uint
  }
)

;; Admin functions
(define-public (toggle-contract-pause)
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (ok (var-set contract-paused (not (var-get contract-paused))))
  )
)

(define-public (create-plan (name (string-ascii 64)) (price uint) (duration uint))
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (asserts! (not (var-get contract-paused)) err-contract-paused)
    (let ((plan-id (var-get next-plan-id)))
      (map-set subscription-plans plan-id
        {
          name: name,
          price: price,
          duration: duration,
          active: true
        }
      )
      (var-set next-plan-id (+ plan-id u1))
      (record-event "PLAN_CREATED" tx-sender name)
      (ok plan-id)
    )
  )
)

(define-public (update-plan (plan-id uint) (new-price uint) (new-duration uint))
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (asserts! (not (var-get contract-paused)) err-contract-paused)
    (match (map-get? subscription-plans plan-id)
      plan (begin
        (map-set subscription-plans plan-id
          (merge plan {
            price: new-price,
            duration: new-duration
          })
        )
        (record-event "PLAN_UPDATED" tx-sender (get name plan))
        (ok true)
      )
      err-invalid-plan
    )
  )
)

;; Subscription functions
(define-public (subscribe (plan-id uint))
  (let (
    (plan (unwrap! (map-get? subscription-plans plan-id) err-invalid-plan))
    (current-time (unwrap-panic (get-block-info? time u0)))
  )
    (asserts! (not (var-get contract-paused)) err-contract-paused)
    (asserts! (get active plan) err-invalid-plan)
    (asserts! (is-none (map-get? subscriptions tx-sender)) err-already-subscribed)
    (try! (stx-transfer? (get price plan) tx-sender contract-owner))
    
    (map-set subscriptions tx-sender
      {
        plan-id: plan-id,
        start-time: current-time,
        end-time: (+ current-time (get duration plan)),
        active: true,
        auto-renew: false
      }
    )
    (record-event "SUBSCRIPTION_CREATED" tx-sender (get name plan))
    (ok true)
  )
)

(define-public (cancel-subscription)
  (let ((sub (unwrap! (map-get? subscriptions tx-sender) err-not-subscribed)))
    (asserts! (not (var-get contract-paused)) err-contract-paused)
    (asserts! (get active sub) err-not-subscribed)
    
    (map-set subscriptions tx-sender
      (merge sub { active: false })
    )
    (record-event "SUBSCRIPTION_CANCELLED" tx-sender "")
    (ok true)
  )
)

;; Helper functions
(define-private (record-event (event-type (string-ascii 20)) (user principal) (data (string-ascii 64)))
  (let ((event-id (+ (var-get last-event-id) u1)))
    (map-set events event-id
      {
        event-type: event-type,
        user: user,
        data: data,
        timestamp: (unwrap-panic (get-block-info? time u0))
      }
    )
    (var-set last-event-id event-id)
    true
  )
)

;; Read only functions
(define-read-only (get-plan (plan-id uint))
  (map-get? subscription-plans plan-id)
)

(define-read-only (get-subscription (subscriber principal))
  (map-get? subscriptions subscriber)
)

(define-read-only (get-contract-status)
  (not (var-get contract-paused))
)

(define-read-only (get-event (event-id uint))
  (map-get? events event-id)
)
