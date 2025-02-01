import {
  Clarinet,
  Tx,
  Chain,
  Account,
  types
} from 'https://deno.land/x/clarinet@v1.0.0/index.ts';
import { assertEquals } from 'https://deno.land/std@0.90.0/testing/asserts.ts';

Clarinet.test({
  name: "Ensure users can register photos and manage access",
  async fn(chain: Chain, accounts: Map<string, Account>) {
    const deployer = accounts.get('deployer')!;
    const user1 = accounts.get('wallet_1')!;
    const user2 = accounts.get('wallet_2')!;

    let block = chain.mineBlock([
      // Register a private photo with encryption
      Tx.contractCall('safe_snap', 'register-photo', [
        types.ascii("QmHash123"),
        types.bool(true),
        types.some(types.ascii("encryptionKey123")),
        types.none()
      ], deployer.address),
    ]);
    
    block.receipts[0].result.expectOk();
    const photoId = block.receipts[0].result.expectOk();

    // Test access control and encryption
    block = chain.mineBlock([
      // Grant access to user1 with encryption key
      Tx.contractCall('safe_snap', 'grant-access', [
        photoId,
        types.principal(user1.address),
        types.some(types.ascii("encryptionKey123"))
      ], deployer.address),
      
      // User1 should be able to get encryption key
      Tx.contractCall('safe_snap', 'get-encryption-key', [
        photoId
      ], user1.address),
    ]);

    block.receipts[0].result.expectOk();
    block.receipts[1].result.expectOk();
  },
});

Clarinet.test({
  name: "Test collections functionality",
  async fn(chain: Chain, accounts: Map<string, Account>) {
    const deployer = accounts.get('deployer')!;
    
    let block = chain.mineBlock([
      // Create a new collection
      Tx.contractCall('safe_snap', 'create-collection', [
        types.ascii("Vacation 2023"),
        types.ascii("Photos from summer vacation")
      ], deployer.address),
    ]);

    const collectionId = block.receipts[0].result.expectOk();

    // Add photo to collection
    block = chain.mineBlock([
      Tx.contractCall('safe_snap', 'register-photo', [
        types.ascii("QmHash456"),
        types.bool(false),
        types.none(),
        types.some(collectionId)
      ], deployer.address),
    ]);

    block.receipts[0].result.expectOk();

    // Verify collection data
    block = chain.mineBlock([
      Tx.contractCall('safe_snap', 'get-collection-photos', [
        collectionId
      ], deployer.address),
    ]);

    block.receipts[0].result.expectOk();
  },
});
