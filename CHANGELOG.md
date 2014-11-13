Changelog
=========

### 0.1.0

Nick Kaye added documentation, and added an additional usage option that aliases the esoteric e.g. `SubscriptionType.SMS` with the more explicit (given that we are returning an ActiveRecord instance) `SubscriptionType.named(:SMS)`.

### 0.0.1

Back in 2007, we started to go in the direction of using constants to represent TYPE. The pattern drove Doug Barth crazy, and at some point he built `acts_as_reference_data` and ran with it.
