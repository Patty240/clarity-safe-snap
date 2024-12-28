;; SafeSnap - Privacy-focused photo sharing contract

;; Constants
(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-not-authorized (err u101))
(define-constant err-already-registered (err u102))
(define-constant err-photo-not-found (err u103))

;; Data structures
(define-map photos
    { photo-id: uint }
    {
        owner: principal,
        ipfs-hash: (string-ascii 64),
        timestamp: uint,
        is-private: bool
    }
)

(define-map access-rights
    { photo-id: uint, user: principal }
    { can-view: bool }
)

(define-map user-photos
    { user: principal }
    { photo-count: uint }
)

;; Data variables
(define-data-var photo-counter uint u0)

;; Private functions
(define-private (is-owner (photo-id uint))
    (let ((photo-data (unwrap! (map-get? photos { photo-id: photo-id }) false)))
        (is-eq tx-sender (get owner photo-data))
    )
)

;; Public functions
(define-public (register-photo (ipfs-hash (string-ascii 64)) (is-private bool))
    (let 
        (
            (photo-id (+ (var-get photo-counter) u1))
            (user-data (default-to { photo-count: u0 } (map-get? user-photos { user: tx-sender })))
        )
        (map-set photos
            { photo-id: photo-id }
            {
                owner: tx-sender,
                ipfs-hash: ipfs-hash,
                timestamp: block-height,
                is-private: is-private
            }
        )
        (map-set user-photos
            { user: tx-sender }
            { photo-count: (+ (get photo-count user-data) u1) }
        )
        (var-set photo-counter photo-id)
        (ok photo-id)
    )
)

(define-public (grant-access (photo-id uint) (user principal))
    (if (is-owner photo-id)
        (begin
            (map-set access-rights
                { photo-id: photo-id, user: user }
                { can-view: true }
            )
            (ok true)
        )
        err-not-authorized
    )
)

(define-public (revoke-access (photo-id uint) (user principal))
    (if (is-owner photo-id)
        (begin
            (map-delete access-rights { photo-id: photo-id, user: user })
            (ok true)
        )
        err-not-authorized
    )
)

;; Read-only functions
(define-read-only (can-view-photo (photo-id uint))
    (let (
        (photo-data (unwrap! (map-get? photos { photo-id: photo-id }) err-photo-not-found))
        (access-data (map-get? access-rights { photo-id: photo-id, user: tx-sender }))
    )
    (ok (or
        (not (get is-private photo-data))
        (is-eq tx-sender (get owner photo-data))
        (get can-view (default-to { can-view: false } access-data))
    )))
)

(define-read-only (get-photo-data (photo-id uint))
    (let ((photo-data (unwrap! (map-get? photos { photo-id: photo-id }) err-photo-not-found)))
        (if (is-eq (unwrap! (can-view-photo photo-id) false) true)
            (ok photo-data)
            err-not-authorized
        )
    )
)

(define-read-only (get-user-photo-count (user principal))
    (ok (get photo-count (default-to { photo-count: u0 } (map-get? user-photos { user: user }))))
)