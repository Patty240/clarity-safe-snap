Clarinet.test({
  name: "Test administrative functions and batch operations",
  async fn(chain: Chain, accounts: Map<string, Account>) {
    const deployer = accounts.get('deployer')!;
    const user1 = accounts.get('wallet_1')!;
    const user2 = accounts.get('wallet_2')!;
    
    // Test contract pause
    let block = chain.mineBlock([
      Tx.contractCall('safe_snap', 'pause-contract', [], deployer.address),
    ]);
    block.receipts[0].result.expectOk();
    
    // Test batch access grant
    const photoIds = [1, 2, 3].map(i => types.uint(i));
    block = chain.mineBlock([
      Tx.contractCall('safe_snap', 'batch-grant-access', [
        types.list(photoIds),
        types.principal(user1.address),
        types.some(types.ascii("tempKey123")),
        types.uint(10)
      ], deployer.address),
    ]);
    block.receipts[0].result.expectErr(types.uint(110)); // Should fail when paused
    
    // Resume contract
    block = chain.mineBlock([
      Tx.contractCall('safe_snap', 'resume-contract', [], deployer.address),
    ]);
    block.receipts[0].result.expectOk();
    
    // Test photo ownership transfer
    block = chain.mineBlock([
      Tx.contractCall('safe_snap', 'transfer-photo-ownership', [
        types.uint(1),
        types.principal(user2.address)
      ], deployer.address),
    ]);
    block.receipts[0].result.expectOk();
  },
});

// [Previous tests remain unchanged]
