# Account deletion test

The Ruby integration test in [`backend/test/account_deletion_test.rb`](../backend/test/account_deletion_test.rb) verifies deletion through the real Rails endpoint and PostgreSQL database, using two synthetic accounts. It covers all six data collections: heart rate, HRV, stress, sleep, steps and activities, including a synthetic GPS route.

| Case | Expected result |
| --- | --- |
| Delete account | HTTP 204; account and all six collections removed; control account and its complete records unchanged. |
| Reuse deleted credentials | Authorization, login and export rejected; repeated deletion remains safe. |
| Invalid credentials | Wrong password, missing token or another account’s token rejected; account data retained. |
| Missing password | HTTP 400; account retained. |
| Database cascade | Associated records removed even when model callbacks are bypassed. |
| Failed deletion | Transaction rolls back; account and associated records retained. |

## Run

From `backend` run:

```sh
DATABASE_URL=postgresql:///ringularity_account_deletion_test RAILS_ENV=test bin/rails db:prepare
DATABASE_URL=postgresql:///ringularity_account_deletion_test RAILS_ENV=test bin/rails test test/account_deletion_test.rb
```

## Result

23 November 2026:

```text
5 runs, 73 assertions, 0 failures, 0 errors, 0 skips
```

**Result: passed.** All associated records were removed and the control account remained unchanged. Environment: local PostgreSQL 18, Ruby 3.4.9 and Rails 8.1.4. 
