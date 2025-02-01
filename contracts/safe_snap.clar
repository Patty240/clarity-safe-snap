;; SafeSnap - Privacy-focused photo sharing contract

;; Constants
(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-not-authorized (err u101)) 
(define-constant err-already-registered (err u102))
(define-constant err-photo-not-found (err u103))
(define-constant err-collection-not-found (err u104))
(define-constant err-invalid-encryption (err u105))

;; Data structures
(define-map photos
    { photo-id: uint }
    {
        owner: principal,
        ipfs-hash: (string-ascii 64),
        timestamp: uint,
        is-private: bool,
        encryption-key: (optional (string-ascii 128)),
        collection-id: (optional uint)
    }
)

(define-map collections
    { collection-id: uint }
    {
        owner: principal,
        name: (string-ascii 64),
        description: (string-ascii 256),
        photo-count: uint
    }
)

(define-map access-rights
    { photo-id: uint, user: principal }
    { can-view: bool, encryption-key: (optional (string-ascii 128)) }
)

(define-map user-photos
    { user: principal }
    { photo-count: uint }
)

;; Data variables  
(define-data-var photo-counter uint u0)
(define-data-var collection-counter uint u0)

;; Private functions
(define-private (is-owner (photo-id uint))
    (let ((photo-data (unwrap! (map-get? photos { photo-id: photo-id }) false)))
        (is-eq tx-sender (get owner photo-data))
    )
)

;; Public functions
(define-public (create-collection (name (string-ascii 64)) (description (string-ascii 256)))
    (let ((collection-id (+ (var-get collection-counter) u1)))
        (map-set collections
            { collection-id: collection-id }
            {
                owner: tx-sender,
                name: name,
                description: description,
                photo-count: u0
            }
        )
        (var-set collection-counter collection-id)
        (ok collection-id)
    )
)

(define-public (register-photo (ipfs-hash (string-ascii 64)) (is-private bool) (encryption-key (optional (string-ascii 128))) (collection-id (optional uint)))
    (let 
        (
            (photo-id (+ (var-get photo-counter) u1))
            (user-data (default-to { photo-count: u0 } (map-get? user-photos { user: tx-sender })))
        )
        ;; Verify collection exists if specified
        (if (is-some collection-id)
            (asserts! (is-some (map-get? collections { collection-id: (unwrap! collection-id err-collection-not-found) })) err-collection-not-found)
            true
        )
        ;; Verify encryption key is provided for private photos
        (asserts! (or (not is-private) (is-some encryption-key)) err-invalid-encryption)
        
        (map-set photos
            { photo-id: photo-id }
            {
                owner: tx-sender,
                ipfs-hash: ipfs-hash,
                timestamp: block-height,
                is-private: is-private,
                encryption-key: encryption-key,
                collection-id: collection-id
            }
        )
        (map-set user-photos
            { user: tx-sender }
            { photo-count: (+ (get photo-count user-data) u1) }
        )
        
        ;; Update collection photo count if part of collection
        (if (is-some collection-id)
            (let ((coll-data (unwrap! (map-get? collections { collection-id: (unwrap! collection-id err-collection-not-found) }) err-collection-not-found)))
                (map-set collections
                    { collection-id: (unwrap! collection-id err-collection-not-found) }
                    (merge coll-data { photo-count: (+ (get photo-count coll-data) u1) })
                )
            )
            true
        )
        
        (var-set photo-counter photo-id)
        (ok photo-id)
    )
)

(define-public (grant-access (photo-id uint) (user principal) (encryption-key (optional (string-ascii 128))))
    (if (is-owner photo-id)
        (begin
            (map-set access-rights
                { photo-id: photo-id, user: user }
                { can-view: true, encryption-key: encryption-key }
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
        (get can-view (default-to { can-view: false, encryption-key: none } access-data))
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

(define-read-only (get-collection-photos (collection-id uint))
    (let ((collection (unwrap! (map-get? collections { collection-id: collection-id }) err-collection-not-found)))
        (ok collection)
    )
)

(define-read-only (get-encryption-key (photo-id uint))
    (let (
        (photo-data (unwrap! (map-get? photos { photo-id: photo-id }) err-photo-not-found))
        (access-data (map-get? access-rights { photo-id: photo-id, user: tx-sender }))
    )
    (if (is-eq (unwrap! (can-view-photo photo-id) false) true)
        (ok (if (is-eq tx-sender (get owner photo-data))
            (get encryption-key photo-data)
            (get encryption-key (default-to { can-view: false, encryption-key: none } access-data))
        ))
        err-not-authorized
    ))
)
