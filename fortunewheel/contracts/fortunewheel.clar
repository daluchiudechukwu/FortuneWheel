;; FortuneWheel - A verifiable on-chain reward distribution system with multiple champions
;; A transparent, decentralized reward system using block information for randomness

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
(define-constant ERR-INVALID-CHAMPIONS (err u109))
(define-constant ERR-TOO-MANY-CHAMPIONS (err u110))
(define-constant ERR-INVALID-ENTRY-FEE (err u111))
(define-constant ERR-INVALID-MIN-PLAYERS (err u112))
(define-constant ERR-INVALID-TIME-LOCK (err u113))

;; Constants for input validation
(define-constant MIN-ENTRY-FEE u100000)  ;; 0.1 STX
(define-constant MAX-ENTRY-FEE u100000000)  ;; 100 STX
(define-constant MAX-MIN-PLAYERS u20)  ;; Maximum value for minimum players
(define-constant TIME-LOCK-LOWER u50)  ;; Minimum value for time-lock
(define-constant TIME-LOCK-UPPER u1000)  ;; Maximum value for time-lock

;; Data variables
(define-data-var game-sequence uint u0)
(define-data-var game-genesis-height uint u0)
(define-data-var entry-fee uint u1000000) ;; 1 STX default
(define-data-var min-participants uint u2)
(define-data-var time-lock uint u100)
(define-data-var champion-count uint u3) ;; Default number of champions
(define-data-var admin principal tx-sender)
(define-data-var last-entropy uint u0)

;; Data maps
(define-map game-rounds
    uint 
    {
        players: (list 50 principal),
        entries: (list 50 uint),
        prize-pool: uint,
        genesis-block: uint,
        finale-block: uint,
        champions: (list 10 {champion: principal, reward: uint}),
        phase: (string-ascii 20),
        entropy: uint
    }
)

(define-map player-entries
    {game-id: uint, player: principal}
    uint
)

;; Helper functions
(define-private (min-of (a uint) (b uint))
    (if (<= a b)
        a
        b))

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

(define-private (generate-entropy)
    (let (
        (current-time (default-to u0 (get-block-info? time block-height)))
        (prev-time (default-to u0 (get-block-info? time (- block-height u1))))
    )
        (mod (+ (* current-time u113) (* prev-time u151)) u1000000000)
    )
)

(define-private (get-random-number (seed uint) (max uint))
    (mod seed max)
)

(define-private (calculate-reward (prize-pool uint) (position uint) (total-champions uint))
    (let (
        (base-reward (/ prize-pool total-champions))
        (bonus (if (is-eq position u0) 
            (mod prize-pool total-champions)
            u0
        ))
    )
        (+ base-reward bonus)
    )
)

(define-private (get-next-champion 
    (champions (list 10 {champion: principal, reward: uint}))
    (players (list 50 principal))
    (seed uint)
    (prize-pool uint)
    (total-champions uint))
    (let (
        (player-count (len players))
        (selected-index (get-random-number seed player-count))
        (champion (unwrap! (element-at players selected-index) champions))
        (current-count (len champions))
    )
        (if (>= current-count total-champions)
            champions
            (unwrap! 
                (as-max-len? 
                    (append champions {
                        champion: champion,
                        reward: (calculate-reward prize-pool current-count total-champions)
                    })
                    u10
                )
                champions
            )
        )
    )
)

(define-private (select-champions (game-id uint) (players (list 50 principal)) (prize-pool uint))
    (let (
        (player-count (len players))
        (champions-needed (min-of (var-get champion-count) player-count))
        (initial-entropy (generate-entropy))
    )
        (if (> champions-needed u0)
            (ok (fold add-champion
                (list u1 u2 u3 u4 u5 u6 u7 u8 u9 u10)
                {
                    champions: (list),
                    candidates: players,
                    seed: initial-entropy,
                    needed: champions-needed,
                    pool: prize-pool
                }
            ))
            (err u100)
        )
    )
)

(define-private (add-champion
    (index uint)
    (state {
        champions: (list 10 {champion: principal, reward: uint}),
        candidates: (list 50 principal),
        seed: uint,
        needed: uint,
        pool: uint
    }))
    (let (
        (current-champions (get champions state))
        (remaining-candidates (get candidates state))
        (current-count (len current-champions))
    )
        (if (>= current-count (get needed state))
            state
            {
                champions: (get-next-champion 
                    current-champions 
                    remaining-candidates 
                    (+ (get seed state) index)
                    (get pool state)
                    (get needed state)
                ),
                candidates: remaining-candidates,
                seed: (get seed state),
                needed: (get needed state),
                pool: (get pool state)
            }
        )
    )
)

;; Public functions
(define-public (start-new-game)
    (let (
        (next-game-id (+ (var-get game-sequence) u1))
        (init-entropy (generate-entropy))
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
                    champions: (list),
                    phase: "running",
                    entropy: init-entropy
                }
            )
            (var-set game-sequence next-game-id)
            (var-set game-genesis-height block-height)
            (var-set last-entropy init-entropy)
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
                    champions: (get champions current-game),
                    phase: (get phase current-game),
                    entropy: (get entropy current-game)
                }
            )
            (ok true)
        )
    )
)

(define-public (select-winners)
    (let (
        (game-id (var-get game-sequence))
        (current-game (unwrap! (map-get? game-rounds game-id) ERR-NO-ACTIVE-GAME))
        (players (get players current-game))
        (player-count (len players))
        (champions-result (try! (select-champions game-id players (get prize-pool current-game))))
    )
        (begin
            (asserts! (>= block-height (+ (get genesis-block current-game) (var-get time-lock))) ERR-TIME-LOCK)
            (asserts! (>= player-count (var-get min-participants)) ERR-EMPTY-POOL)
            (asserts! (is-eq (get phase current-game) "running") ERR-GAME-COMPLETE)
            
            (let (
                (final-champions (get champions champions-result))
            )
                (begin
                    ;; Update game with champions
                    (map-set game-rounds game-id
                        (merge current-game 
                            {
                                champions: final-champions,
                                phase: "finished",
                                entropy: (var-get last-entropy)
                            }
                        )
                    )
                    
                    ;; Transfer rewards to champions
                    (map transfer-reward final-champions)
                    
                    (ok final-champions)
                )
            )
        )
    )
)

(define-private (transfer-reward (champion {champion: principal, reward: uint}))
    (as-contract (stx-transfer? 
        (get reward champion)
        tx-sender 
        (get champion champion)
    ))
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

(define-read-only (get-champion-count)
    (var-get champion-count)
)

(define-read-only (get-last-entropy)
    (var-get last-entropy)
)

;; Admin functions
(define-public (set-entry-fee (new-fee uint))
    (begin
        (asserts! (is-eq tx-sender (var-get admin)) ERR-UNAUTHORIZED)
        (asserts! (and 
            (>= new-fee MIN-ENTRY-FEE)
            (<= new-fee MAX-ENTRY-FEE)
        ) ERR-INVALID-ENTRY-FEE)
        (var-set entry-fee new-fee)
        (ok true)
    )
)

(define-public (set-min-participants (new-min uint))
    (begin
        (asserts! (is-eq tx-sender (var-get admin)) ERR-UNAUTHORIZED)
        (asserts! (and 
            (> new-min u0)
            (<= new-min MAX-MIN-PLAYERS)
        ) ERR-INVALID-MIN-PLAYERS)
        (var-set min-participants new-min)
        (ok true)
    )
)

(define-public (set-time-lock (new-lock uint))
    (begin
        (asserts! (is-eq tx-sender (var-get admin)) ERR-UNAUTHORIZED)
        (asserts! (and 
            (>= new-lock TIME-LOCK-LOWER)
            (<= new-lock TIME-LOCK-UPPER)
        ) ERR-INVALID-TIME-LOCK)
        (var-set time-lock new-lock)
        (ok true)
    )
)

(define-public (set-champion-count (new-count uint))
    (begin
        (asserts! (is-eq tx-sender (var-get admin)) ERR-UNAUTHORIZED)
        (asserts! (<= new-count u10) ERR-TOO-MANY-CHAMPIONS)
        (asserts! (> new-count u0) ERR-INVALID-CHAMPIONS)
        (var-set champion-count new-count)
        (ok true)
    )
)