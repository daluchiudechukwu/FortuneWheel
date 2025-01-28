;; FortuneWheel - A verifiable on-chain reward distribution system
;; A transparent, decentralized reward system using block properties for randomness

;; Error codes
(define-constant ERR-UNAUTHORIZED (err u100))
(define-constant ERR-GAME-RUNNING (err u101))
(define-constant ERR-NO-ACTIVE-GAME (err u102))
(define-constant ERR-LOW-BALANCE (err u103))
(define-constant ERR-DUPLICATE-ENTRY (err u104))
(define-constant ERR-EMPTY-POOL (err u105))
(define-constant ERR-TIME-LOCK (err u106))
(define-constant ERR-BAD-AMOUNT (err u107))
(define-constant ERR-GAME-COMPLETE (err u108))

;; Data variables
(define-data-var game-sequence uint u0)
(define-data-var game-genesis-height uint u0)
(define-data-var entry-fee uint u1000000) ;; 1 STX default
(define-data-var min-participants uint u2)
(define-data-var time-lock uint u100)
(define-data-var admin principal tx-sender)

;; Data maps
(define-map game-rounds
    uint 
    {
        players: (list 50 principal),
        entries: (list 50 uint),
        prize-pool: uint,
        genesis-block: uint,
        finale-block: uint,
        champion: (optional principal),
        phase: (string-ascii 20)
    }
)

(define-map player-entries
    {game-id: uint, player: principal}
    uint
)

;; Private functions
(define-private (can-initiate)
    (let (
        (current-game (unwrap! (map-get? game-rounds (var-get game-sequence)) false))
    )
        (or 
            (is-eq (get phase current-game) "finished")
            (is-eq (get phase current-game) "terminated")
        )
    )
)

(define-private (is-running)
    (let (
        (current-game (unwrap! (map-get? game-rounds (var-get game-sequence)) false))
    )
        (and
            (is-eq (get phase current-game) "running")
            (>= block-height (get genesis-block current-game))
            (<= block-height (get finale-block current-game))
        )
    )
)

(define-private (generate-random)
    (let (
        (current-time (unwrap! (get-block-info? time block-height) u0))
        (prev-time (unwrap! (get-block-info? time (- block-height u1)) u0))
    )
        (+ current-time prev-time)
    )
)

;; Public functions
(define-public (start-new-game)
    (let (
        (next-game-id (+ (var-get game-sequence) u1))
    )
        (begin
            (asserts! (is-eq tx-sender (var-get admin)) ERR-UNAUTHORIZED)
            (asserts! (can-initiate) ERR-GAME-RUNNING)
            
            (map-set game-rounds next-game-id 
                {
                    players: (list),
                    entries: (list),
                    prize-pool: u0,
                    genesis-block: block-height,
                    finale-block: (+ block-height (var-get time-lock)),
                    champion: none,
                    phase: "running"
                }
            )
            (var-set game-sequence next-game-id)
            (var-set game-genesis-height block-height)
            (ok next-game-id)
        )
    )
)

(define-public (enter-game)
    (let (
        (game-id (var-get game-sequence))
        (current-game (unwrap! (map-get? game-rounds game-id) ERR-NO-ACTIVE-GAME))
        (current-players (get players current-game))
        (current-entries (get entries current-game))
    )
        (begin
            (asserts! (is-running) ERR-NO-ACTIVE-GAME)
            (asserts! (>= (stx-get-balance tx-sender) (var-get entry-fee)) ERR-LOW-BALANCE)
            
            ;; Transfer STX to contract
            (try! (stx-transfer? (var-get entry-fee) tx-sender (as-contract tx-sender)))
            
            ;; Update player entries
            (map-set player-entries 
                {game-id: game-id, player: tx-sender}
                (+ (default-to u0 (map-get? player-entries 
                    {game-id: game-id, player: tx-sender})) u1)
            )
            
            ;; Update game data
            (map-set game-rounds game-id
                {
                    players: (unwrap! (as-max-len? 
                        (append current-players tx-sender) u50) ERR-GAME-COMPLETE),
                    entries: (unwrap! (as-max-len? 
                        (append current-entries (len current-entries)) u50) ERR-GAME-COMPLETE),
                    prize-pool: (+ (get prize-pool current-game) (var-get entry-fee)),
                    genesis-block: (get genesis-block current-game),
                    finale-block: (get finale-block current-game),
                    champion: (get champion current-game),
                    phase: (get phase current-game)
                }
            )
            (ok true)
        )
    )
)

(define-public (select-winner)
    (let (
        (game-id (var-get game-sequence))
        (current-game (unwrap! (map-get? game-rounds game-id) ERR-NO-ACTIVE-GAME))
        (players (get players current-game))
        (player-count (len players))
    )
        (begin
            (asserts! (>= block-height (+ (get genesis-block current-game) (var-get time-lock))) ERR-TIME-LOCK)
            (asserts! (>= player-count (var-get min-participants)) ERR-EMPTY-POOL)
            (asserts! (is-eq (get phase current-game) "running") ERR-GAME-COMPLETE)
            
            (let (
                (chosen-index (mod (generate-random) player-count))
                (winner (unwrap! (element-at players chosen-index) ERR-EMPTY-POOL))
            )
                (begin
                    ;; Update game with winner
                    (map-set game-rounds game-id
                        (merge current-game 
                            {
                                champion: (some winner),
                                phase: "finished"
                            }
                        )
                    )
                    
                    ;; Transfer prize to winner
                    (try! (as-contract (stx-transfer? 
                        (get prize-pool current-game)
                        tx-sender 
                        winner
                    )))
                    
                    (ok winner)
                )
            )
        )
    )
)

;; Read-only functions
(define-read-only (get-game-info (game-id uint))
    (map-get? game-rounds game-id)
)

(define-read-only (get-player-entries (game-id uint) (player principal))
    (map-get? player-entries {game-id: game-id, player: player})
)

(define-read-only (get-current-game)
    (get-game-info (var-get game-sequence))
)

(define-read-only (get-entry-fee)
    (var-get entry-fee)
)

;; Admin functions
(define-public (set-entry-fee (new-fee uint))
    (begin
        (asserts! (is-eq tx-sender (var-get admin)) ERR-UNAUTHORIZED)
        (var-set entry-fee new-fee)
        (ok true)
    )
)

(define-public (set-min-participants (new-min uint))
    (begin
        (asserts! (is-eq tx-sender (var-get admin)) ERR-UNAUTHORIZED)
        (var-set min-participants new-min)
        (ok true)
    )
)

(define-public (set-time-lock (new-lock uint))
    (begin
        (asserts! (is-eq tx-sender (var-get admin)) ERR-UNAUTHORIZED)
        (var-set time-lock new-lock)
        (ok true)
    )
)