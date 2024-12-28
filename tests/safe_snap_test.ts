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
      // Register a private photo
      Tx.contractCall('safe_snap', 'register-photo', [
        types.ascii("QmHash123"),
        types.bool(true)
      ], deployer.address),
    ]);
    
    // Check photo registration
    block.receipts[0].result.expectOk();
    const photoId = block.receipts[0].result.expectOk();

    // Test access control
    block = chain.mineBlock([
      // User1 should not be able to view the photo initially
      Tx.contractCall('safe_snap', 'can-view-photo', [
        photoId
      ], user1.address),
      
      // Grant access to user1
      Tx.contractCall('safe_snap', 'grant-access', [
        photoId,
        types.principal(user1.address)
      ], deployer.address),
      
      // User1 should now be able to view the photo
      Tx.contractCall('safe_snap', 'can-view-photo', [
        photoId
      ], user1.address),
      
      // Revoke access from user1
      Tx.contractCall('safe_snap', 'revoke-access', [
        photoId,
        types.principal(user1.address)
      ], deployer.address)
    ]);

    assertEquals(block.receipts[0].result.expectOk(), false);
    block.receipts[1].result.expectOk();
    assertEquals(block.receipts[2].result.expectOk(), true);
    block.receipts[3].result.expectOk();
  },
});

Clarinet.test({
  name: "Test photo visibility and ownership checks",
  async fn(chain: Chain, accounts: Map<string, Account>) {
    const deployer = accounts.get('deployer')!;
    const user1 = accounts.get('wallet_1')!;

    let block = chain.mineBlock([
      // Register a public photo
      Tx.contractCall('safe_snap', 'register-photo', [
        types.ascii("QmHash456"),
        types.bool(false)
      ], deployer.address),
      
      // Register a private photo
      Tx.contractCall('safe_snap', 'register-photo', [
        types.ascii("QmHash789"),
        types.bool(true)
      ], deployer.address)
    ]);

    const publicPhotoId = block.receipts[0].result.expectOk();
    const privatePhotoId = block.receipts[1].result.expectOk();

    // Test photo visibility
    block = chain.mineBlock([
      // Anyone should be able to view public photo
      Tx.contractCall('safe_snap', 'can-view-photo', [
        publicPhotoId
      ], user1.address),
      
      // User1 should not be able to view private photo
      Tx.contractCall('safe_snap', 'can-view-photo', [
        privatePhotoId
      ], user1.address)
    ]);

    assertEquals(block.receipts[0].result.expectOk(), true);
    assertEquals(block.receipts[1].result.expectOk(), false);
  },
});