import {
  Clarinet,
  Tx,
  Chain,
  Account,
  types
} from 'https://deno.land/x/clarinet@v1.0.0/index.ts';
import { assertEquals } from 'https://deno.land/std@0.90.0/testing/asserts.ts';

Clarinet.test({
  name: "Ensure that only owner can create plans",
  async fn(chain: Chain, accounts: Map<string, Account>) {
    const deployer = accounts.get("deployer")!;
    const wallet1 = accounts.get("wallet_1")!;

    let block = chain.mineBlock([
      Tx.contractCall("flexnest", "create-plan", 
        [types.ascii("Basic Plan"), types.uint(100), types.uint(2592000)],
        deployer.address
      ),
      Tx.contractCall("flexnest", "create-plan",
        [types.ascii("Premium Plan"), types.uint(200), types.uint(2592000)],
        wallet1.address
      )
    ]);

    assertEquals(block.receipts[0].result, '(ok u1)');
    assertEquals(block.receipts[1].result, '(err u100)');
  },
});

Clarinet.test({
  name: "Can subscribe to an existing plan and cancel subscription",
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
      Tx.contractCall("flexnest", "cancel-subscription",
        [],
        wallet1.address
      )
    ]);

    assertEquals(block.receipts[1].result, '(ok true)');
    assertEquals(block.receipts[2].result, '(ok true)');
  },
});

Clarinet.test({
  name: "Contract pause functionality works correctly",
  async fn(chain: Chain, accounts: Map<string, Account>) {
    const deployer = accounts.get("deployer")!;
    const wallet1 = accounts.get("wallet_1")!;

    let block = chain.mineBlock([
      Tx.contractCall("flexnest", "toggle-contract-pause",
        [],
        deployer.address
      ),
      Tx.contractCall("flexnest", "create-plan",
        [types.ascii("Basic Plan"), types.uint(100), types.uint(2592000)],
        deployer.address
      )
    ]);

    assertEquals(block.receipts[0].result, '(ok true)');
    assertEquals(block.receipts[1].result, '(err u105)');
  },
});
