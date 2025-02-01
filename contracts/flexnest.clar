;; FlexNest Contract

;; Constants
(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-invalid-plan (err u101))
(define-constant err-already-subscribed (err u102))
(define-constant err-not-subscribed (err u103))
(define-constant err-insufficient-balance (err u104))

;; Data vars
(define-data-var next-plan-id uint u1)

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
    active: bool
  }
)

;; Public functions
(define-public (create-plan (name (string-ascii 64)) (price uint) (duration uint))
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
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
      (ok plan-id)
    )
  )
)

(define-public (subscribe (plan-id uint))
  (let (
    (plan (unwrap! (map-get? subscription-plans plan-id) err-invalid-plan))
    (current-time (unwrap-panic (get-block-info? time u0)))
  )
    (asserts! (get active plan) err-invalid-plan)
    (asserts! (is-none (map-get? subscriptions tx-sender)) (err-already-subscribed))
    
    (map-set subscriptions tx-sender
      {
        plan-id: plan-id,
        start-time: current-time,
        end-time: (+ current-time (get duration plan)),
        active: true
      }
    )
    (ok true)
  )
)

;; Read only functions
(define-read-only (get-plan (plan-id uint))
  (map-get? subscription-plans plan-id)
)

(define-read-only (get-subscription (subscriber principal))
  (map-get? subscriptions subscriber)
)
