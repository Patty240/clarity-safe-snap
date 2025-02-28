// [Previous test content remains, adding new tests below]

Clarinet.test({
  name: "Test temporary access and photo deletion",
  async fn(chain: Chain, accounts: Map<string, Account>) {
    const deployer = accounts.get('deployer')!;
    const user1 = accounts.get('wallet_1')!;
    
    // Register photo
    let block = chain.mineBlock([
      Tx.contractCall('safe_snap', 'register-photo', [
        types.ascii("QmHash789"),
        types.bool(true),
        types.some(types.ascii("encryptionKey789")),
        types.none()
      ], deployer.address),
    ]);
    
    const photoId = block.receipts[0].result.expectOk();
    
    // Grant temporary access
    block = chain.mineBlock([
      Tx.contractCall('safe_snap', 'grant-temporary-access', [
        photoId,
        types.principal(user1.address),
        types.some(types.ascii("tempKey123")),
        types.uint(10)
      ], deployer.address),
    ]);
    
    block.receipts[0].result.expectOk();
    
    // Delete photo
    block = chain.mineBlock([
      Tx.contractCall('safe_snap', 'delete-photo', [
        photoId
      ], deployer.address),
    ]);
    
    block.receipts[0].result.expectOk();
  },
});
