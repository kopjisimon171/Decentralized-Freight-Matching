(define-constant ERR_UNAUTHORIZED u1000)
(define-constant ERR_INVALID_AMOUNT u1001)
(define-constant ERR_ALREADY_FUNDED u1002)
(define-constant ERR_NOT_FUNDED u1003)
(define-constant ERR_ALREADY_RELEASED u1004)
(define-constant ERR_ALREADY_CANCELLED u1005)
(define-constant ERR_DEADLINE_NOT_REACHED u1006)
(define-constant ERR_INVALID_ESCROW u1007)
(define-constant ERR_NOT_SHIPPER u1008)
(define-constant ERR_NOT_CARRIER u1009)
(define-constant ERR_NO_ACTION_AVAILABLE u1010)

(define-constant CONTRACT_SELF (as-contract tx-sender))

(define-data-var escrow-counter uint u0)

(define-map escrows
  uint
  {
    shipper: principal,
    carrier: principal,
    amount: uint,
    funded: bool,
    delivered: bool,
    released: bool,
    cancelled: bool,
    deadline: uint
  }
)

(define-private (get-next-escrow-id)
  (let (
    (current (var-get escrow-counter))
    (next-id (+ current u1))
  )
    (var-set escrow-counter next-id)
    next-id
  )
)

(define-public (create-escrow (carrier principal) (amount uint) (deadline uint))
  (begin
    (asserts! (> amount u0) (err ERR_INVALID_AMOUNT))
    (asserts! (> deadline stacks-block-height) (err ERR_UNAUTHORIZED))
    (let (
      (escrow-id (get-next-escrow-id))
    )
      (map-set escrows escrow-id
        {
          shipper: tx-sender,
          carrier: carrier,
          amount: amount,
          funded: false,
          delivered: false,
          released: false,
          cancelled: false,
          deadline: deadline
        }
      )
      (ok escrow-id)
    )
  )
)

(define-public (fund-escrow (escrow-id uint))
  (let (
    (escrow (unwrap! (map-get? escrows escrow-id) (err ERR_INVALID_ESCROW)))
    (amount (get amount escrow))
    (shipper (get shipper escrow))
  )
    (asserts! (is-eq tx-sender shipper) (err ERR_NOT_SHIPPER))
    (asserts! (not (get funded escrow)) (err ERR_ALREADY_FUNDED))
    (asserts! (> amount u0) (err ERR_INVALID_AMOUNT))
    (asserts! (>= (stx-get-balance shipper) amount) (err ERR_INVALID_AMOUNT))
    (try! (stx-transfer? amount shipper CONTRACT_SELF))
    (map-set escrows escrow-id (merge escrow {funded: true}))
    (ok true)
  )
)

(define-public (mark-delivered (escrow-id uint))
  (let (
    (escrow (unwrap! (map-get? escrows escrow-id) (err ERR_INVALID_ESCROW)))
    (shipper (get shipper escrow))
  )
    (asserts! (is-eq tx-sender shipper) (err ERR_NOT_SHIPPER))
    (asserts! (get funded escrow) (err ERR_NOT_FUNDED))
    (asserts! (not (get released escrow)) (err ERR_ALREADY_RELEASED))
    (asserts! (not (get cancelled escrow)) (err ERR_ALREADY_CANCELLED))
    (map-set escrows escrow-id (merge escrow {delivered: true}))
    (ok true)
  )
)

(define-public (withdraw (escrow-id uint))
  (let (
    (escrow (unwrap! (map-get? escrows escrow-id) (err ERR_INVALID_ESCROW)))
    (carrier (get carrier escrow))
    (amount (get amount escrow))
  )
    (asserts! (is-eq tx-sender carrier) (err ERR_NOT_CARRIER))
    (asserts! (get funded escrow) (err ERR_NOT_FUNDED))
    (asserts! (get delivered escrow) (err ERR_NO_ACTION_AVAILABLE))
    (asserts! (not (get released escrow)) (err ERR_ALREADY_RELEASED))
    (asserts! (not (get cancelled escrow)) (err ERR_ALREADY_CANCELLED))
    (try! (as-contract (stx-transfer? amount CONTRACT_SELF carrier)))
    (map-set escrows escrow-id (merge escrow {released: true}))
    (ok true)
  )
)

(define-public (refund (escrow-id uint))
  (let (
    (escrow (unwrap! (map-get? escrows escrow-id) (err ERR_INVALID_ESCROW)))
    (shipper (get shipper escrow))
    (amount (get amount escrow))
    (deadline (get deadline escrow))
  )
    (asserts! (is-eq tx-sender shipper) (err ERR_NOT_SHIPPER))
    (asserts! (get funded escrow) (err ERR_NOT_FUNDED))
    (asserts! (not (get released escrow)) (err ERR_ALREADY_RELEASED))
    (asserts! (not (get cancelled escrow)) (err ERR_ALREADY_CANCELLED))
    (asserts! (>= stacks-block-height deadline) (err ERR_DEADLINE_NOT_REACHED))
    (try! (as-contract (stx-transfer? amount CONTRACT_SELF shipper)))
    (map-set escrows escrow-id (merge escrow {cancelled: true}))
    (ok true)
  )
)

(define-read-only (get-escrow (escrow-id uint))
  (map-get? escrows escrow-id)
)

(define-read-only (get-escrow-counter)
  (var-get escrow-counter)
)
