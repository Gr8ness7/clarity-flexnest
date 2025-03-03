import {
  Clarinet,
  Tx,
  Chain,
  Account,
  types
} from 'https://deno.land/x/clarinet@v1.0.0/index.ts';
import { assertEquals } from 'https://deno.land/std@0.90.0/testing/asserts.ts';

// Previous tests remain...

Clarinet.test({
  name: "Auto-renewal functionality works correctly",
  async fn(chain: Chain, accounts: Map<string, Account>) {
    const deployer = accounts.get("deployer")!;
    const wallet1 = accounts.get("wallet_1")!;

    let block = chain.mineBlock([
      Tx.contractCall("flexnest", "create-plan",
        [types.ascii("Basic Plan"), types.uint(100), types.uint(2592000)],
        deployer.address
      ),
      Tx.contractCall("flexnest", "subscribe",
        [types.uint(1)],
        wallet1.address
      ),
      Tx.contractCall("flexnest", "set-auto-renew",
        [types.bool(true)],
        wallet1.address
      )
    ]);

    assertEquals(block.receipts[2].result, '(ok true)');
    
    // Simulate time passing
    chain.mineEmptyBlockUntil(2592000);
    
    let renewalBlock = chain.mineBlock([
      Tx.contractCall("flexnest", "process-renewal",
        [types.principal(wallet1.address)],
        deployer.address
      )
    ]);

    assertEquals(renewalBlock.receipts[0].result, '(ok true)');
  },
});
