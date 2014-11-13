[![MIT License][license-image]][license-url] [![Build Status][travis-image]][travis-url]

Caches all the reference data and provides Model.CODE and MODEL.description for the classes it's included in.

## Documentation

### Basic Usage

For example, `SubscriptionType` is an ActiveRecord:

    require 'acts_as_reference_data'

    class SubscriptionType < ActiveRecord::Base
      acts_as_reference_data
    end

It's assumed that migrations have been created to populate this table with various types, e.g. `SMS` or `EMAIL`.

This allows us to reference these database objects with consistent pointers from the codebase. Some developers dislike this approach, but we are thoroughly entrenched, so read it and weep:

    if criteria_type == :mobile_number
      send_verification_message_to_mobile(verification_code, user, @amoe_form.campaign)
      subscription_type = SubscriptionType.SMS
    else
      send_verification_message_to_email_address(verification_code, criteria, @amoe_form.campaign, user.id)
      subscription_type = SubscriptionType.EMAIL
    end

NOTE: `SubscriptionType.SMS` returns an instance of ActiveRecord for the record corresponding to `SMS`.

From there, we have access to `.code` and other reference data:

    def populate_campaign_prompt
      if params['sub_type'] == SubscriptionType.SMS.code
        render :partial =>'sms_prompt'
      elsif params['sub_type'] == SubscriptionType.EMAIL.code
        render :partial => 'email_prompt'
      end
    end
    
## [Changelog](CHANGELOG.md)

## License

Count.js is freely distributable under the terms of the [MIT license](LICENSE).

[license-image]: http://img.shields.io/badge/license-MIT-blue.svg?style=flat
[license-url]: MIT-LICENSE

[travis-url]: http://travis-ci.org/signal/acts_as_reference_data
[travis-image]: http://img.shields.io/travis/signal/acts_as_reference_data/master.svg?style=flat
