;; Project Name: Terra Renewal DAO
;; A decentralized autonomous organization for funding regenerative agriculture practices
;; Allows token holders to submit, vote on, and fund sustainable farming proposals

;; Constants
(define-constant contract-owner tx-sender)
(define-constant dao-name "Terra Renewal")
(define-constant min-proposal-amount u1000) ;; Minimum STX required for proposal
(define-constant voting-period u144) ;; ~1 day in blocks (assuming 10 min block time)
(define-constant execution-delay u72) ;; ~12 hours in blocks

;; Error codes
(define-constant ERR-NOT-AUTHORIZED u401)
(define-constant ERR-PROPOSAL-EXISTS u402)
(define-constant ERR-PROPOSAL-EXPIRED u403)
(define-constant ERR-PROPOSAL-ACTIVE u404)
(define-constant ERR-INSUFFICIENT-BALANCE u405)
(define-constant ERR-PROPOSAL-NOT-FOUND u406)
(define-constant ERR-ALREADY-VOTED u407)
(define-constant ERR-VOTING-CLOSED u408)
(define-constant ERR-EXECUTION-DELAY u409)

;; Data structures
(define-map proposals
  { id: uint }
  {
    creator: principal,
    title: (string-ascii 100),
    description: (string-ascii 500),
    farm-location: (string-ascii 100),
    amount: uint,
    sustainable-practices: (list 5 (string-ascii 50)),
    yes-votes: uint,
    no-votes: uint,
    status: (string-ascii 20),
    created-at: uint,
    executed-at: uint
  }
)

(define-map votes
  { proposal-id: uint, voter: principal }
  { vote: bool }
)

(define-map token-balances
  { owner: principal }
  { balance: uint }
)

;; Variables
(define-data-var proposal-count uint u0)
(define-data-var total-token-supply uint u1000000) ;; 1 million tokens initially

;; Initialize the DAO with tokens for contract owner
(begin
  (map-set token-balances
    { owner: contract-owner }
    { balance: (var-get total-token-supply) }
  )
)

;; Tokens and governance functions
(define-read-only (get-balance (owner principal))
  (default-to u0
    (get balance (map-get? token-balances { owner: owner }))
  )
)

(define-public (transfer (recipient principal) (amount uint))
  (let ((sender-balance (get-balance tx-sender)))
    (if (>= sender-balance amount)
      (begin
        (map-set token-balances
          { owner: tx-sender }
          { balance: (- sender-balance amount) }
        )
        (map-set token-balances
          { owner: recipient }
          { balance: (+ (get-balance recipient) amount) }
        )
        (ok true)
      )
      (err ERR-INSUFFICIENT-BALANCE)
    )
  )
)

;; Proposal management
(define-read-only (get-proposal (id uint))
  (map-get? proposals { id: id })
)

(define-read-only (get-proposal-count)
  (var-get proposal-count)
)

(define-public (create-proposal 
    (title (string-ascii 100))
    (description (string-ascii 500))
    (farm-location (string-ascii 100))
    (amount uint)
    (sustainable-practices (list 5 (string-ascii 50)))
  )
  (let ((proposal-id (+ (var-get proposal-count) u1))
        (sender-balance (get-balance tx-sender)))
    
    ;; Check if sender has enough tokens to create proposal
    (if (>= sender-balance min-proposal-amount)
      (begin
        (var-set proposal-count proposal-id)
        (map-set proposals
          { id: proposal-id }
          {
            creator: tx-sender,
            title: title,
            description: description,
            farm-location: farm-location,
            amount: amount,
            sustainable-practices: sustainable-practices,
            yes-votes: u0,
            no-votes: u0,
            status: "active",
            created-at: block-height,
            executed-at: u0
          }
        )
        (ok proposal-id)
      )
      (err ERR-INSUFFICIENT-BALANCE)
    )
  )
)

(define-public (vote-on-proposal (proposal-id uint) (vote-value bool))
  (let ((proposal (unwrap! (get-proposal proposal-id) (err ERR-PROPOSAL-NOT-FOUND)))
        (voter-balance (get-balance tx-sender))
        (vote-exists (is-some (map-get? votes { proposal-id: proposal-id, voter: tx-sender }))))
    
    ;; Make sure proposal is still active and voting period hasn't ended
    (if (> (+ (get created-at proposal) voting-period) block-height)
      (if (not vote-exists)
        (begin
          ;; Record the vote
          (map-set votes
            { proposal-id: proposal-id, voter: tx-sender }
            { vote: vote-value }
          )
          
          ;; Update vote tallies - Fixed the issue here
          (if vote-value
            ;; If yes vote
            (map-set proposals
              { id: proposal-id }
              (merge proposal
                { yes-votes: (+ (get yes-votes proposal) voter-balance) }
              )
            )
            ;; If no vote
            (map-set proposals
              { id: proposal-id }
              (merge proposal
                { no-votes: (+ (get no-votes proposal) voter-balance) }
              )
            )
          )
          (ok true)
        )
        (err ERR-ALREADY-VOTED)
      )
      (err ERR-VOTING-CLOSED)
    )
  )
)

(define-public (finalize-proposal (proposal-id uint))
  (let ((proposal (unwrap! (get-proposal proposal-id) (err ERR-PROPOSAL-NOT-FOUND)))
        (proposal-end-height (+ (get created-at proposal) voting-period)))
    
    ;; Check if voting period is over
    (if (< proposal-end-height block-height)
      ;; Check if execution delay is satisfied
      (if (> block-height (+ proposal-end-height execution-delay))
        (if (is-eq (get status proposal) "active")
          (begin
            ;; Update proposal status based on votes
            (map-set proposals
              { id: proposal-id }
              (merge proposal {
                status: (if (> (get yes-votes proposal) (get no-votes proposal))
                          "approved"
                          "rejected"),
                executed-at: block-height
              })
            )
            (ok true)
          )
          (err ERR-PROPOSAL-EXPIRED)
        )
        (err ERR-EXECUTION-DELAY)
      )
      (err ERR-PROPOSAL-ACTIVE)
    )
  )
)

;; Admin functions
(define-public (mint-tokens (recipient principal) (amount uint))
  (begin
    (asserts! (is-eq tx-sender contract-owner) (err ERR-NOT-AUTHORIZED))
    (let ((current-balance (get-balance recipient)))
      (map-set token-balances
        { owner: recipient }
        { balance: (+ current-balance amount) }
      )
      (var-set total-token-supply (+ (var-get total-token-supply) amount))
      (ok true)
    )
  )
)

;; Fund distribution for approved proposals
(define-public (release-funds (proposal-id uint) (recipient principal))
  (let ((proposal (unwrap! (get-proposal proposal-id) (err ERR-PROPOSAL-NOT-FOUND))))
    (asserts! (is-eq tx-sender contract-owner) (err ERR-NOT-AUTHORIZED))
    (asserts! (is-eq (get status proposal) "approved") (err ERR-PROPOSAL-EXPIRED))
    
    ;; Transfer STX to the recipient (farmer)
    (as-contract (stx-transfer? (get amount proposal) tx-sender recipient))
  )
)