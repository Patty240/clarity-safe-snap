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
        photo-count: uint
    }
)

(define-map access-rights
    { photo-id: uint, user: principal }
    { 
        can-view: bool, 
        encryption-key: (optional (string-ascii 128)),
        expiry: (optional uint)
    }
)

(define-map user-photos
    { user: principal }
    { photo-count: uint }
)

;; Data variables  
(define-data-var photo-counter uint u0)
(define-data-var collection-counter uint u0)

;; Events
(define-data-var last-event-id uint u0)

(define-private (emit-event (event-type (string-ascii 12)) (data (string-ascii 256)))
    (let ((event-id (+ (var-get last-event-id) u1)))
        (print { event-id: event-id, type: event-type, data: data })
        (var-set last-event-id event-id)
    )
)

;; Private functions
(define-private (is-owner (photo-id uint))
    (let ((photo-data (unwrap! (map-get? photos { photo-id: photo-id }) false)))
        (is-eq tx-sender (get owner photo-data))
    )
)

(define-private (validate-access (photo-id uint) (user principal))
    (let ((access-data (map-get? access-rights { photo-id: photo-id, user: user })))
        (match (get expiry (default-to { can-view: false, encryption-key: none, expiry: none } access-data))
            expiry-height (< block-height expiry-height)
            true
        )
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
        (emit-event "COLL_CREATED" (concat (to-ascii collection-id) name))
        (ok collection-id)
    )
)

;; ... [Previous functions remain unchanged]

(define-public (delete-photo (photo-id uint))
    (let ((photo-data (unwrap! (map-get? photos { photo-id: photo-id }) err-photo-not-found)))
        (asserts! (is-owner photo-id) err-not-authorized)
        (map-delete photos { photo-id: photo-id })
        (emit-event "PHOTO_DELETE" (concat (to-ascii photo-id) "deleted"))
        (ok true)
    )
)

(define-public (grant-temporary-access (photo-id uint) (user principal) (encryption-key (optional (string-ascii 128))) (duration uint))
    (if (is-owner photo-id)
        (begin
            (asserts! (> duration u0) err-invalid-expiry)
            (map-set access-rights
                { photo-id: photo-id, user: user }
                { 
                    can-view: true, 
                    encryption-key: encryption-key,
                    expiry: (some (+ block-height duration))
                }
            )
            (emit-event "ACCESS_GRANT" (concat (to-ascii photo-id) (principal-to-string user)))
            (ok true)
        )
        err-not-authorized
    )
)

;; ... [Remaining read-only functions unchanged]
