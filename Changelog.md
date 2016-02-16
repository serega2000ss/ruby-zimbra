## v 0.7.30

### Added

#### Accounts

* Enable Account Archiving: `enable_archive(cos_id, archive_account_name)`
* Disabled Account Archiving: `disable_archive()`
* Is account archiving enabled?: `archive_enabled?`
* What is the archive mailbox: `archive_account`

### v 0.7.30

#### Domain

* Added method `set_max_accounts`, to enable account quotas per domain

### v 0.7.29

#### DistributionList

* Added methods `add_members` and `remove_members` with take a Email o Array of
Emails and return the updated List object.
