;; SafeSnap - Privacy-focused photo sharing contract

;; Constants
(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-not-authorized (err u101)) 
(define-constant err-already-registered (err u102))
(define-constant err-photo-not-found (err u103))
(define-constant err-collection-not-found (err u104))
(define-constant err-invalid-encryption (err u105))
(define-constant err-expired-access (err u106))
(define-constant err-invalid-expiry (err u107))
(define-constant err-invalid-batch (err u108))
(define-constant err-transfer-failed (err u109))
(define-constant err-contract-paused (err u110))

;; Contract status
(define-data-var contract-paused bool false)

;; Data structures
(define-map photos
    { photo-id: uint }
    {
        owner: principal,
        ipfs-hash: (string-ascii 64),
        timestamp: uint,
        is-private: bool,
        encryption-key: (optional (string-ascii 128)),
        collection-id: (optional uint),
        version: uint
    }
)

(define-map collections
    { collection-id: uint }
    {
        owner: principal,
        name: (string-ascii 64),
        description: (string-ascii 256),
        photo-count: uint,
        version: uint
    }
)

(define-map access-rights
    { photo-id: uint, user: principal }
    { 
        can-view: bool, 
        encryption-key: (optional (string-ascii 128)),
        expiry: (optional uint),
        granted-at: uint
    }
)

(define-map user-photos
    { user: principal }
    { photo-count: uint }
)

;; Data variables  
(define-data-var photo-counter uint u0)
(define-data-var collection-counter uint u0)
(define-data-var last-event-id uint u0)

;; Administrative functions
(define-public (pause-contract)
    (begin
        (asserts! (is-eq tx-sender contract-owner) err-owner-only)
        (var-set contract-paused true)
        (emit-event "CONTRACT" "paused")
        (ok true)
    )
)

(define-public (resume-contract)
    (begin
        (asserts! (is-eq tx-sender contract-owner) err-owner-only)
        (var-set contract-paused false)
        (emit-event "CONTRACT" "resumed")
        (ok true)
    )
)

;; Enhanced event emission
(define-private (emit-event (event-type (string-ascii 12)) (data (string-ascii 256)))
    (let ((event-id (+ (var-get last-event-id) u1)))
        (print { 
            event-id: event-id, 
            type: event-type, 
            data: data,
            timestamp: block-height 
        })
        (var-set last-event-id event-id)
    )
)

;; Batch operations
(define-public (batch-grant-access 
    (photo-ids (list 10 uint)) 
    (user principal) 
    (encryption-key (optional (string-ascii 128))) 
    (duration uint)
)
    (begin
        (asserts! (not (var-get contract-paused)) err-contract-paused)
        (asserts! (> (len photo-ids) u0) err-invalid-batch)
        (map-batch-grant photo-ids user encryption-key duration)
        (emit-event "BATCH_ACCESS" (concat (to-ascii (len photo-ids)) (principal-to-string user)))
        (ok true)
    )
)

(define-private (map-batch-grant 
    (photo-ids (list 10 uint)) 
    (user principal) 
    (encryption-key (optional (string-ascii 128))) 
    (duration uint)
)
    (map 
        (lambda (photo-id)
            (grant-temporary-access photo-id user encryption-key duration)
        )
        photo-ids
    )
)

;; Photo ownership transfer
(define-public (transfer-photo-ownership (photo-id uint) (new-owner principal))
    (let ((photo-data (unwrap! (map-get? photos { photo-id: photo-id }) err-photo-not-found)))
        (asserts! (not (var-get contract-paused)) err-contract-paused)
        (asserts! (is-owner photo-id) err-not-authorized)
        (map-set photos
            { photo-id: photo-id }
            (merge photo-data { 
                owner: new-owner,
                version: (+ (get version photo-data) u1)
            })
        )
        (emit-event "PHOTO_TRANS" (concat (to-ascii photo-id) (principal-to-string new-owner)))
        (ok true)
    )
)

;; [Previous functions remain unchanged]
