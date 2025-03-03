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
(define-constant err-invalid-duration (err u107))
(define-constant err-invalid-price (err u108))
(define-constant err-renewal-failed (err u109))

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
    auto-renew: bool,
    last-renewal: uint
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
    (asserts! (> duration u0) err-invalid-duration)
    (asserts! (> price u0) err-invalid-price)
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

;; Enhanced subscription functions
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
        auto-renew: false,
        last-renewal: current-time
      }
    )
    (record-event "SUBSCRIPTION_CREATED" tx-sender (get name plan))
    (ok true)
  )
)

(define-public (set-auto-renew (auto-renew bool))
  (let ((sub (unwrap! (map-get? subscriptions tx-sender) err-not-subscribed)))
    (asserts! (not (var-get contract-paused)) err-contract-paused)
    (asserts! (get active sub) err-not-subscribed)
    
    (map-set subscriptions tx-sender
      (merge sub { auto-renew: auto-renew })
    )
    (record-event "AUTO_RENEW_UPDATED" tx-sender (if auto-renew "enabled" "disabled"))
    (ok true)
  )
)

(define-public (process-renewal (subscriber principal))
  (let (
    (sub (unwrap! (map-get? subscriptions subscriber) err-not-subscribed))
    (plan (unwrap! (map-get? subscription-plans (get plan-id sub)) err-invalid-plan))
    (current-time (unwrap-panic (get-block-info? time u0)))
  )
    (asserts! (not (var-get contract-paused)) err-contract-paused)
    (asserts! (get active sub) err-not-subscribed)
    (asserts! (get auto-renew sub) err-renewal-failed)
    (asserts! (>= current-time (get end-time sub)) err-renewal-failed)
    
    (try! (stx-transfer? (get price plan) subscriber contract-owner))
    
    (map-set subscriptions subscriber
      (merge sub {
        start-time: current-time,
        end-time: (+ current-time (get duration plan)),
        last-renewal: current-time
      })
    )
    (record-event "SUBSCRIPTION_RENEWED" subscriber (get name plan))
    (ok true)
  )
)

;; Previous functions remain unchanged...
