(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_NOT_AUTHORIZED (err u100))
(define-constant ERR_JOB_NOT_FOUND (err u101))
(define-constant ERR_INSUFFICIENT_PAYMENT (err u102))
(define-constant ERR_JOB_ALREADY_TAKEN (err u103))
(define-constant ERR_INVALID_STATUS (err u104))
(define-constant ERR_NOT_DRIVER (err u105))
(define-constant ERR_NOT_SHIPPER (err u106))
(define-constant ERR_DELIVERY_TIMEOUT (err u107))
(define-constant ERR_INSUFFICIENT_STAKE (err u108))
(define-constant ERR_DISPUTE_EXISTS (err u109))
(define-constant ERR_NO_DISPUTE (err u110))

(define-constant MIN_STAKE u1000000)
(define-constant PLATFORM_FEE_PERCENT u2)
(define-constant DELIVERY_TIMEOUT_BLOCKS u1440)
(define-constant DISPUTE_TIMEOUT_BLOCKS u2880)

(define-data-var job-counter uint u0)
(define-data-var dispute-counter uint u0)

(define-map jobs
  uint
  {
    shipper: principal,
    driver: (optional principal),
    pickup-location: (string-ascii 100),
    delivery-location: (string-ascii 100),
    payment-amount: uint,
    stake-required: uint,
    status: (string-ascii 20),
    created-at: uint,
    accepted-at: (optional uint),
    completed-at: (optional uint),
    description: (string-ascii 500)
  }
)

(define-map user-profiles
  principal
  {
    reputation-score: uint,
    completed-jobs: uint,
    failed-jobs: uint,
    total-earnings: uint,
    is-active: bool
  }
)

(define-map job-stakes
  uint
  {
    driver: principal,
    stake-amount: uint,
    staked-at: uint
  }
)

(define-map disputes
  uint
  {
    job-id: uint,
    initiator: principal,
    reason: (string-ascii 200),
    status: (string-ascii 20),
    created-at: uint,
    resolved-at: (optional uint),
    resolution: (optional (string-ascii 200))
  }
)

(define-private (get-platform-fee (amount uint))
  (/ (* amount PLATFORM_FEE_PERCENT) u100)
)

(define-private (calculate-reputation-score (completed uint) (failed uint))
  (if (is-eq (+ completed failed) u0)
    u100
    (/ (* completed u100) (+ completed failed))
  )
)

(define-private (update-user-profile (user principal) (earnings uint) (success bool))
  (let (
    (current-profile (default-to 
      {reputation-score: u100, completed-jobs: u0, failed-jobs: u0, total-earnings: u0, is-active: true}
      (map-get? user-profiles user)
    ))
  )
    (map-set user-profiles user
      {
        reputation-score: (calculate-reputation-score 
          (if success (+ (get completed-jobs current-profile) u1) (get completed-jobs current-profile))
          (if success (get failed-jobs current-profile) (+ (get failed-jobs current-profile) u1))
        ),
        completed-jobs: (if success (+ (get completed-jobs current-profile) u1) (get completed-jobs current-profile)),
        failed-jobs: (if success (get failed-jobs current-profile) (+ (get failed-jobs current-profile) u1)),
        total-earnings: (+ (get total-earnings current-profile) earnings),
        is-active: (get is-active current-profile)
      }
    )
  )
)

(define-public (post-job 
  (pickup-location (string-ascii 100))
  (delivery-location (string-ascii 100))
  (payment-amount uint)
  (stake-required uint)
  (description (string-ascii 500))
)
  (let (
    (job-id (+ (var-get job-counter) u1))
    (platform-fee (get-platform-fee payment-amount))
    (total-required (+ payment-amount platform-fee))
  )
    (asserts! (>= (stx-get-balance tx-sender) total-required) ERR_INSUFFICIENT_PAYMENT)
    (asserts! (>= stake-required MIN_STAKE) ERR_INSUFFICIENT_STAKE)
    
    (try! (stx-transfer? total-required tx-sender (as-contract tx-sender)))
    
    (map-set jobs job-id
      {
        shipper: tx-sender,
        driver: none,
        pickup-location: pickup-location,
        delivery-location: delivery-location,
        payment-amount: payment-amount,
        stake-required: stake-required,
        status: "posted",
        created-at: stacks-block-height,
        accepted-at: none,
        completed-at: none,
        description: description
      }
    )
    
    (var-set job-counter job-id)
    (ok job-id)
  )
)

(define-public (accept-job (job-id uint))
  (let (
    (job (unwrap! (map-get? jobs job-id) ERR_JOB_NOT_FOUND))
    (stake-amount (get stake-required job))
  )
    (asserts! (is-eq (get status job) "posted") ERR_INVALID_STATUS)
    (asserts! (>= (stx-get-balance tx-sender) stake-amount) ERR_INSUFFICIENT_STAKE)
    
    (try! (stx-transfer? stake-amount tx-sender (as-contract tx-sender)))
    
    (map-set jobs job-id (merge job {
      driver: (some tx-sender),
      status: "accepted",
      accepted-at: (some stacks-block-height)
    }))
    
    (map-set job-stakes job-id {
      driver: tx-sender,
      stake-amount: stake-amount,
      staked-at: stacks-block-height
    })
    
    (ok true)
  )
)

(define-public (confirm-pickup (job-id uint))
  (let (
    (job (unwrap! (map-get? jobs job-id) ERR_JOB_NOT_FOUND))
  )
    (asserts! (is-eq (some tx-sender) (get driver job)) ERR_NOT_DRIVER)
    (asserts! (is-eq (get status job) "accepted") ERR_INVALID_STATUS)
    
    (map-set jobs job-id (merge job {status: "in-transit"}))
    (ok true)
  )
)

(define-public (confirm-delivery (job-id uint))
  (let (
    (job (unwrap! (map-get? jobs job-id) ERR_JOB_NOT_FOUND))
    (driver (unwrap! (get driver job) ERR_NOT_DRIVER))
    (stake-info (unwrap! (map-get? job-stakes job-id) ERR_JOB_NOT_FOUND))
  )
    (asserts! (is-eq tx-sender driver) ERR_NOT_DRIVER)
    (asserts! (is-eq (get status job) "in-transit") ERR_INVALID_STATUS)
    
    (map-set jobs job-id (merge job {
      status: "completed",
      completed-at: (some stacks-block-height)
    }))
    
    (try! (as-contract (stx-transfer? (get payment-amount job) tx-sender driver)))
    (try! (as-contract (stx-transfer? (get stake-amount stake-info) tx-sender driver)))
    
    (update-user-profile driver (get payment-amount job) true)
    (update-user-profile (get shipper job) u0 true)
    
    (ok true)
  )
)

(define-public (cancel-job (job-id uint))
  (let (
    (job (unwrap! (map-get? jobs job-id) ERR_JOB_NOT_FOUND))
    (platform-fee (get-platform-fee (get payment-amount job)))
  )
    (asserts! (is-eq tx-sender (get shipper job)) ERR_NOT_SHIPPER)
    (asserts! (is-eq (get status job) "posted") ERR_INVALID_STATUS)
    
    (map-set jobs job-id (merge job {status: "cancelled"}))
    
    (try! (as-contract (stx-transfer? (get payment-amount job) tx-sender (get shipper job))))
    
    (ok true)
  )
)

(define-public (handle-timeout (job-id uint))
  (let (
    (job (unwrap! (map-get? jobs job-id) ERR_JOB_NOT_FOUND))
    (accepted-at (unwrap! (get accepted-at job) ERR_INVALID_STATUS))
    (driver (unwrap! (get driver job) ERR_NOT_DRIVER))
    (stake-info (unwrap! (map-get? job-stakes job-id) ERR_JOB_NOT_FOUND))
  )
    (asserts! (>= stacks-block-height (+ accepted-at DELIVERY_TIMEOUT_BLOCKS)) ERR_DELIVERY_TIMEOUT)
    (asserts! (or (is-eq (get status job) "accepted") (is-eq (get status job) "in-transit")) ERR_INVALID_STATUS)
    
    (map-set jobs job-id (merge job {status: "failed"}))
    
    (try! (as-contract (stx-transfer? (get payment-amount job) tx-sender (get shipper job))))
    
    (update-user-profile driver u0 false)
    (update-user-profile (get shipper job) u0 false)
    
    (ok true)
  )
)

(define-public (create-dispute (job-id uint) (reason (string-ascii 200)))
  (let (
    (job (unwrap! (map-get? jobs job-id) ERR_JOB_NOT_FOUND))
    (dispute-id (+ (var-get dispute-counter) u1))
  )
    (asserts! (or 
      (is-eq tx-sender (get shipper job))
      (is-eq (some tx-sender) (get driver job))
    ) ERR_NOT_AUTHORIZED)
    
    (asserts! (or 
      (is-eq (get status job) "in-transit")
      (is-eq (get status job) "completed")
    ) ERR_INVALID_STATUS)
    
    (map-set disputes dispute-id {
      job-id: job-id,
      initiator: tx-sender,
      reason: reason,
      status: "pending",
      created-at: stacks-block-height,
      resolved-at: none,
      resolution: none
    })
    
    (var-set dispute-counter dispute-id)
    (ok dispute-id)
  )
)

(define-public (resolve-dispute 
  (dispute-id uint) 
  (resolution (string-ascii 200))
  (favor-driver bool)
)
  (let (
    (dispute (unwrap! (map-get? disputes dispute-id) ERR_NO_DISPUTE))
    (job-id (get job-id dispute))
    (job (unwrap! (map-get? jobs job-id) ERR_JOB_NOT_FOUND))
    (driver (unwrap! (get driver job) ERR_NOT_DRIVER))
    (stake-info (unwrap! (map-get? job-stakes job-id) ERR_JOB_NOT_FOUND))
  )
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_NOT_AUTHORIZED)
    (asserts! (is-eq (get status dispute) "pending") ERR_INVALID_STATUS)
    
    (map-set disputes dispute-id (merge dispute {
      status: "resolved",
      resolved-at: (some stacks-block-height),
      resolution: (some resolution)
    }))
    
    (if favor-driver
      (begin
        (try! (as-contract (stx-transfer? (get payment-amount job) tx-sender driver)))
        (try! (as-contract (stx-transfer? (get stake-amount stake-info) tx-sender driver)))
        (update-user-profile driver (get payment-amount job) true)
        (update-user-profile (get shipper job) u0 false)
      )
      (begin
        (try! (as-contract (stx-transfer? (get payment-amount job) tx-sender (get shipper job))))
        (update-user-profile driver u0 false)
        (update-user-profile (get shipper job) u0 true)
      )
    )
    
    (ok true)
  )
)

(define-read-only (get-job (job-id uint))
  (map-get? jobs job-id)
)

(define-read-only (get-user-profile (user principal))
  (map-get? user-profiles user)
)

(define-read-only (get-dispute (dispute-id uint))
  (map-get? disputes dispute-id)
)

(define-read-only (get-job-stake (job-id uint))
  (map-get? job-stakes job-id)
)

(define-read-only (get-contract-balance)
  (stx-get-balance (as-contract tx-sender))
)

(define-read-only (get-job-counter)
  (var-get job-counter)
)

(define-read-only (get-dispute-counter)
  (var-get dispute-counter)
)
