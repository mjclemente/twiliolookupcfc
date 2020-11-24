# twiliolookupcfc

A CFML wrapper for the [Twilio Lookup API](https://www.twilio.com/docs/lookup/api).
Use Twilio's Lookup API to retrieve information about phone numbers, including region-specific formatting, carrier information, and caller name.

*Feel free to use the issue tracker to report bugs or suggest improvements!*

## Acknowledgements

This project borrows heavily from the API frameworks built by [jcberquist](https://github.com/jcberquist). Thanks to John for all the inspiration!

## Table of Contents

- [Quick Start](#quick-start)
- [Setup and Authentication](#setup-and-authentication)
- [`twiliolookupcfc` Reference Manual](#reference-manual)

## Quick Start

The following is a quick example of using this wrapper to look up carrier information for a phone number.

```cfc
twiliolookup = new path.to.twiliolookupcfc.twiliolookup( accountSid = 'xxx', authToken = 'xxx' );

result = twiliolookup.carrier( '+19998675309' );

writeDump( var='#result#', abort='true' );
```

### Setup and Authentication

To get started with the Twilio Lookup API, you'll need your Twilio account SID and your auth token. You can find your account SID and auth token in your [console](https://www.twilio.com/console).

You can provide the SID/token to this wrapper manually when creating the component, as in the Quick Start example above, or via an environment variables named `TWILIO_ACCOUNT_SID` and `TWILIO_AUTH_TOKEN`. They will get picked up automatically. This latter approach is generally preferable, as it keeps hardcoded credentials out of your codebase.

### Reference Manual

#### `caller( required string phoneNumber,  string CountryCode="" ,  string AddOns="" ,  struct AddOnsData="[runtime expression]"  )`

Convenience method for looking up caller information. Set's the `Type` parameter in the lookup to `caller-name`.

#### `callerAndCarrier( required string phoneNumber,  string CountryCode="" ,  string AddOns="" ,  struct AddOnsData="[runtime expression]"  )`

Convenience method for looking up both caller and carrier information. Set's the `Type` parameter in the lookup to `['carrier','caller-name']`.

#### `carrier( required string phoneNumber,  string CountryCode="" ,  string AddOns="" ,  struct AddOnsData="[runtime expression]"  )`

Convenience method for looking up carrier information about the number. Set's the `Type` parameter in the lookup to `carrier`.

#### `phoneNumber( required string phoneNumber,  string CountryCode="" ,  any Type="" ,  string AddOns="" ,  struct AddOnsData="[runtime expression]"  )`

Returns phone number information matching the specified request. Formatting information is standard. Carrier, Caller Name, and phone number type information can be requested, in addition to using Add-ons to access 3rd party data sources. The parameter `Type` can be: `carrier` or `caller-name`. Defaults to null. For both, pass in an array with both values.. *[Endpoint docs](https://www.twilio.com/docs/lookup/api#lookup-a-phone-number)*

---
