Changelog

## 2.0.1
- Add `continuations_slash_delimit_end_of_line_only` to options. This option allows parsing continuation records that begin with a slash character (`/`).

## 2.0.0
- Add parameters for whether or not we use account summaries for account control checksum. We now include it by default. To disable it `account_control_ignores_summary_amounts` should passed into `options` This is the only breaking change.
- Allow for optional "as of" times on the Group header.

## 1.0.0
- Initial Release
