# SafeSnap

A privacy-focused photo-sharing platform built on the Stacks blockchain. SafeSnap allows users to securely share photos with specific recipients while maintaining ownership and control over their content.

## Features
- Upload photo metadata and access controls
- Grant/revoke access to specific users
- Track photo ownership history
- End-to-end encryption support
- Photo collections and albums
- Granular access control with encryption key management

## Architecture
The contract implements a secure photo management system with the following key components:
- Photo registration and ownership tracking
- Access control management
- Permission verification
- Photo metadata storage
- Encryption key management
- Collections and album organization

## Collections
Users can now organize their photos into collections (albums). Each collection has:
- Unique identifier
- Name and description
- Photo count tracking
- Owner permissions

## Encryption
The platform now supports end-to-end encryption:
- Encryption keys can be specified for private photos
- Keys are securely shared with authorized users
- Granular control over key distribution
- Support for different encryption keys per user
