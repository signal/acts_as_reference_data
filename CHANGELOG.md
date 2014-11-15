Changelog
=========

### 0.1.1

Nick Kaye added documentation, and added an additional usage option that aliases the esoteric e.g. `SubscriptionType.SMS` with the more explicit (given that we are returning an ActiveRecord instance) `SubscriptionType.named(:SMS)`.

### 0.0.1

Back in 2007, we started to go in the direction of using constants to represent TYPE. The pattern was insufficient, and at some point  Doug Barth built `acts_as_reference_data` to replace it.
