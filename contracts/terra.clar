;; Project Name: Terra Renewal DAO
;; A decentralized autonomous organization for funding regenerative agriculture practices
;; Allows token holders to submit, vote on, and fund sustainable farming projects

;; Constants
(define-constant contract-owner tx-sender)
(define-constant dao-name "Terra Renewal")
(define-constant min-proposal-amount u1000) ;; Minimum tokens required for proposal
(define-constant voting-period u144) ;; ~1 day in blocks (assuming 10 min block time)
(define-constant execution-delay u72) ;; ~12 hours in blocks
(define-constant max-transfer-amount u1000000) ;; Safety limit on transfers

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
(define-constant ERR-INVALID-AMOUNT u410)
(define-constant ERR-INVALID-RECIPIENT u411)
(define-constant ERR-MAX-SUPPLY-REACHED u412)

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
(define-data-var max-token-supply uint u10000000) ;; 10 million tokens cap

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
    ;; Validate inputs
    (asserts! (not (is-eq recipient tx-sender)) (err ERR-INVALID-RECIPIENT))
    (asserts! (> amount u0) (err ERR-INVALID-AMOUNT))
    (asserts! (<= amount max-transfer-amount) (err ERR-INVALID-AMOUNT))
    (asserts! (>= sender-balance amount) (err ERR-INSUFFICIENT-BALANCE))
    ;; Removed invalid principal-destruct? check
    
    ;; Execute transfer
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
    
    ;; Validate inputs
    (asserts! (> amount u0) (err ERR-INVALID-AMOUNT))
    (asserts! (>= sender-balance min-proposal-amount) (err ERR-INSUFFICIENT-BALANCE))
    (asserts! (<= amount u100000000) (err ERR-INVALID-AMOUNT)) ;; Cap proposal amount
    (asserts! (> (len title) u0) (err ERR-INVALID-AMOUNT))
    (asserts! (> (len description) u0) (err ERR-INVALID-AMOUNT))
    (asserts! (> (len farm-location) u0) (err ERR-INVALID-AMOUNT))
    (asserts! (> (len sustainable-practices) u0) (err ERR-INVALID-AMOUNT))
    
    ;; Create proposal
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
)

(define-public (vote-on-proposal (proposal-id uint) (vote-value bool))
  (let ((proposal (unwrap! (get-proposal proposal-id) (err ERR-PROPOSAL-NOT-FOUND)))
        (voter-balance (get-balance tx-sender))
        (vote-exists (is-some (map-get? votes { proposal-id: proposal-id, voter: tx-sender }))))
    
    ;; Validate proposal state
    (asserts! (> voter-balance u0) (err ERR-INSUFFICIENT-BALANCE))
    (asserts! (> (+ (get created-at proposal) voting-period) block-height) (err ERR-VOTING-CLOSED))
    (asserts! (not vote-exists) (err ERR-ALREADY-VOTED))
    
    ;; Record the vote
    (map-set votes
      { proposal-id: proposal-id, voter: tx-sender }
      { vote: vote-value }
    )
    
    ;; Update vote tallies
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
)

(define-public (finalize-proposal (proposal-id uint))
  (let ((proposal (unwrap! (get-proposal proposal-id) (err ERR-PROPOSAL-NOT-FOUND)))
        (proposal-end-height (+ (get created-at proposal) voting-period)))
    
    ;; Validate proposal state for finalization
    (asserts! (< proposal-end-height block-height) (err ERR-PROPOSAL-ACTIVE))
    (asserts! (> block-height (+ proposal-end-height execution-delay)) (err ERR-EXECUTION-DELAY))
    (asserts! (is-eq (get status proposal) "active") (err ERR-PROPOSAL-EXPIRED))
    
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
)

;; Admin functions
(define-public (mint-tokens (recipient principal) (amount uint))
  (begin
    ;; Validate admin and inputs
    (asserts! (is-eq tx-sender contract-owner) (err ERR-NOT-AUTHORIZED))
    (asserts! (> amount u0) (err ERR-INVALID-AMOUNT))
    (asserts! (<= amount u1000000) (err ERR-INVALID-AMOUNT))
    ;; Removed invalid principal-destruct? check
    
    ;; Check max supply
    (let ((new-supply (+ (var-get total-token-supply) amount)))
      (asserts! (<= new-supply (var-get max-token-supply)) (err ERR-MAX-SUPPLY-REACHED))
      
      ;; Execute minting
      (map-set token-balances
        { owner: recipient }
        { balance: (+ (get-balance recipient) amount) }
      )
      (var-set total-token-supply new-supply)
      (ok true)
    )
  )
)

;; Fund distribution for approved proposals
(define-public (release-funds (proposal-id uint) (recipient principal))
  (let ((proposal (unwrap! (get-proposal proposal-id) (err ERR-PROPOSAL-NOT-FOUND))))
    ;; Validate state and authorization
    (asserts! (is-eq tx-sender contract-owner) (err ERR-NOT-AUTHORIZED))
    (asserts! (is-eq (get status proposal) "approved") (err ERR-PROPOSAL-EXPIRED))
    ;; Removed invalid principal-destruct? check
    
    ;; Verify recipient is the proposal creator
    (asserts! (is-eq recipient (get creator proposal)) (err ERR-NOT-AUTHORIZED))
    
    ;; Transfer STX to the recipient (farmer)
    (as-contract (stx-transfer? (get amount proposal) tx-sender recipient))
  )
)