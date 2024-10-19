# Changelog

## Unreleased

## Version 0.15.0

## Added
- Support for MJML campaigns.
- Forms can now be configured to redirect users after successful submission and when double opt-in
  is required.
- Forms can now be configured with a custom message when double opt-in is required

## Improved
- New email scheduler and rate limiter with significantly improved performance. (thanks @dompie
  for supporting the development of this feature)

## Fixed
- Show correct state while campaign is being prepared for sending on stats page
- Marking custom checkboxes as *required* actually requires users to check them now.
  Fixes #328. (thanks @cyberwuulf for reporting)


## Version 0.14.11
## Changed
- Increased database timeout when inserting recipients to 60 seconds


## Version 0.14.10
## Changed
- The analytics UI now shows a maximum of 20 links to avoid performance issues
  with large campaigns and individualized links


## Version 0.14.9
## Fixed
- Enabled translation of system strings on public forms.


## Version 0.14.8
## Added
- Campaigns with type `block` and `json_body` can now be created via the API. Implements #300 (thanks @dompie for suggesting)


## Version 0.14.7
## Added
- Image blocks now allow the use of Liquid in `src` and other attributes.
  Fixes #297 (thanks @dompie for reporting)

## Fixed
- Separators are now rendered more faithfully in the block editor


## Version 0.14.6

## Added
- Added PATCH and POST API endpoints for updating just the data field of a
  contact

## Fixed
- Liquid tags are now correctly rendered in layout blocks in the Block Editor
  (thanks @dompie for reporting)
- Fixed bug that caused "starts with" and "ends with" to be inverted in
  segment editor (thanks @dompie for reporting)


## Version 0.14.5

## Changed
- Creating and updating contacts via the API now allows setting the `status`
  field.
- Contacts list is now sorted in decending order by default

## Fixed
- Segments are now guaranteed to be initialized with a valid (empty) filter,
  avoiding potential crashes with `nil` filters.
- `MAILER_SMTP_FROM_EMAIL` is now used for sending system emails again.


## Version 0.14.4

## Fixed
- Avoid potential partial merging of system sender config with user-configured senders


## Version 0.14.3

## Fixed
- Only support TLSv1.2 for STARTTLS SMTP Senders to avoid issues with
  non-compliant TLSv1.3 implementation in OTP

## Version 0.14.2

## Improved
- Added new Gmail user agent to avoid tracking invalid clicks/opens
- Return to list of unsubscribed/unreachable contacts after delete action from
  one of those pages. Implements #193 (thanks @digitalfredy for reporting)
- It's now possible to choose between the US and EU API endpoints for Mailgun senders (thanks @harryfear for reporting)
- Improvements to German translation (thanks @dompie)

## Fixed
- Clicking "Delete all" on the contacts list no longer causes a server error
  when no contacts have been selected. Fixes #260 (thanks @CSDUMMI for reporting)
- Fixed connection errors when using SMTP senders with STARTTLS (thanks @beep and @CodeOfTim for reporting)


## Version 0.14.0

Custom signup form fields + contacts search 🔎

### Added
- Custom fields (text, checkbox, dropdown, tags, numbers) can now be added to
  contact signup forms. Implements #135
- Search and sorting on contacts page
- Added buttons for inserting images, links, and buttons to plain Markdown
  editor. Fixes #255 (thanks @lukaprincic for suggesting)

## Improved
- Errors in signup forms are displayed with a prominent red border and bold text
  now.

### Fixed
- If the `status` column is present in a CSV import, only rows where this column
  is set to "active" are imported. Fixes #253 (thanks @VZsI for reporting)
- Live preview in plain Markdown editor no longer disappears when switching to
  rich editor and back.
- Fixed error when saving a contact with JSON data and a constraint error


## Version 0.13.1

### Fixed
- API Contact response now includes status field
- Fixed error when using custom email template for double opt-in emails


## Version 0.13.0

Double Opt-In ✅

### Added
- Added support for double opt-in/confirmed opt in.
  Forms can now be configured to enable double opt-in to require new subscribers
  to confirm their email address before they are added as contacts to the
  project.

### Changed
- Updated Elixir to 1.15
- Translatable labels for first name and last name in form builder
- Refactored Form controller to separate config UI from public routes
- Refactored how form submissions are processed
- Refactored how Markdown campaigns are built

### Fixed
- Added support for additional JPEG variant (this avoids errors when uploading
  previously unrecognized JPEG files)


## Version 0.12.8

### Added
- Added `MAILER_ENABLE_STARTTLS` option to configure a system mailer with STARTTLS (#247)

### Fixed
- API DELETE endpoints for campaigns, contacts, segments now return the
  correct 204 response


## Version 0.12.7

### Added
- Added `MAILER_ENABLE_SSL` option to configure a system mailer with SSL/TLS

### Fixed
- Markdown campaigns now allow adding links to images (#245)


## Version 0.12.6

### Fixed
- Fixed SSL/TLS errors when sending emails with SMTP senders
- Fixed potential exception for image blocks without captions/urls

### Added
- CSV download for contacts and segments (#238 - thanks @katafrakt)
- Improved configuration form for SMTP senders with automatic port selection
  depending on security mode


## Version 0.12.5

### Fixed
- Fixed crash when using data URLs in campaigns (#218 - thanks @katafrakt)

## Version 0.12.4

### Added
- Support for Captchas from [Friendly Captcha](https://friendlycaptcha.com/) (thanks @beeb)

### Changed
- Segments are now ordered alphabetically (#203 - thanks @panoramix360)


## Version 0.12.3

### Changed
- Failed campaign emails are now logged via `Logger.warning/1` instead of
  `Logger.debug/1`.


## Version 0.12.2

### Fixed
- Email preview text is now actually included in emails
- Layout blocks now have a default 1:1 ratio, ensuring they are always rendered
  correctly


## Version 0.12.1

New Campaign Block Editor 📝

### Added
- New block-style editor for building campaigns
  - Multi-column layouts
  - Headings, paragraphs, lists
  - Images
  - Buttons
  - Blockquotes
  - Spacers
- More styling options in the form editor (#185)

### Changed
- Changed base email template to [Cerberus Hybrid](https://www.cerberusemail.com/hybrid-responsive)
- Scheduled campaigns that could not be delivered are automatically un-scheduled
- Scrolling position in template and campaign previews is retained when changes are made

### Fixed
- Invalid signature markup no longer breaks the template editor (#119)
- Fixed error that caused uploaded images not to show up in upload modal (#186)
- Fixed some broken URLs when Keila is configured with `URL_PATH` (#189)
- Mailer port now defaults to `587` instead of `nil` (#182 - thanks @aej)
- Fixed bug that could cause the content of a Markdown campaign to be erased when changing the title (#188)
- Fixed bug that could cause the segment page to crash (#177)


## Version 0.11.2

### Changed
- Only hard bounces are shown as bounces on campaign statistics page

### Fixed
- Legacy IDs are now decoded correctly

## Version 0.11.1

Better Campaign Analytics 📈

### Added

- New Campaign Analytics page
- Improved Contact Activity Stream
- Separate lists for active/unsubscribed/unreachable contacts
- Improved handling and logging of campaign delivery errors
- Bot detection in campaign open tracking (#164 - thanks @panoramix360)
- New API endpoint to list Senders (#147)
- Added support for Postmark senders (thanks @aej)

### Changed
- Improved compatibility with SMTP servers by relaxing `gen_smtp` SSL/TLS settings
- Upgraded to Elixir 1.14
- Ugraded to Tailwind 3
- Added success hint when copying API key to clipboard

### Fixed
- Fixed error when no user content dir is set (#171)
- Fixed error when CSRF is enabled for forms (#167)
- **Breaking:** Hashids now use configurable salt. Read more on [keila.io](https://www.keila.io/updates/breaking-hashid-update)

## Version 0.10.0

Image Uploads, Rate Limits, Do-not-track Campaigns 🖼️

### Added
- Image Uploads
- Do-not-track option for campaigns
- Liquid templating support in campaign subjects
- First interface translation added: German
- Rate limits for Senders and Shared Senders (thanks @gbottari & @panoramix360!)
- Allow configuring `FROM` email address for system emails
- Shared local sender for testing/development
- Improved styling: New spacer block and additional styling for signatures
- Configurable FROM email address for system emails

### Changed
- Updated LiveView to 0.17
- Images in the WYSIWYG editor can now be modified on double-click
- Easier configuration of public-facing Keila URLs

### Fixed
- API keys don’t expire anymore
- Fixed some typos (thanks @kianmeng!)
- Liquid tags can be used as link targets now


## Version 0.9.0

Campaign Data, Improved WYSIWYG editor 💽

### Added
- Campaign data feature
- Automatic recognition of Markdown in WYSIWYG editor
- New *Code* button in WYSIWYG editor with Liquid template examples
- Highlighting of Liquid tags in WYSIWYG editor
- Pretty-printing of embedded form HTML
- Support for Dev Containers

### Changed
- Updated JS dependencies
- Added size constraint to contact data field (8 KB per contact)
- Simplified UI for campaign editor with settings moved to modal
- Link click statistics are now displayed live while campaign is sending

### Fixed
- Use full URL for embedded form action attribute


## Version 0.8.0

API for Contacts & Campaigns, Better Imports, UX Improvements 🧑‍💻

### Added
- API for managing Contacts, Campaigns, Segments
- Swagger UI for API at `/api`
- Improved contact import with support for custom data and upserts
- Notifications when leaving pages with unsaved data
- Added `DB_ENABLE_SSL` configuration option

### Changed
- Updated Oban and Jason dependencies

### Fixed
- Segments with custom data fields can now be edited after saving
- Error display in campaigns without sender no longer keeps reloading page


## Version 0.7.1
### Fixed
- Fixed error when creating new segments


## Version 0.7.0

### Added
- Contact segmentation
- Support for custom contact data
- Allow deletion of sent campaigns

### Changed
- Improved UI design
- Moved all templates from leex/eex to heex
- Improved Core querying API

### Fixed
- Fixed exception when processing unhandled SES webhooks

## Version 0.6.2

### Added
- Configuration option to run Keila in a subdirectory
- Login-as feature for admins
- Gzip compression of assets

### Changed
- Upgraded to Phoenix 1.6
- Upgraded various dependencies, including Ecto
- Replaced Webpack with esbuild


## Version 0.6.1

### Fixed
- Default contact status is now *subscribed*


## Version 0.6.0

Contact Activity Log & Bounce Handling 🗒️

### Changed
- Upon unsubscribing, contacts are no longer deleted from the database

### Added
- Contact activity log
- Contact dashboard with subscriber numbers
- Support for Configuration Sets for AWS SES
- Automatic handling of bounces and complaints for AWS SES


## Version 0.5.4

### Changed
- Removed password placeholder texts

### Fixed
- Dockerfile and sample docker-compose configuration are now compatible


## Version 0.5.3

### Added
- Template now fully compatible with Outlook and Windows Mail

### Fixed
- Fixed broken CSV template downloads
- Improved template display in WYSIWG editor


## Version 0.5.2

### Fixed
- Fixed broken styling on non-authenticated routes


## Version 0.5.1

### Added
- Improved onboarding experience with empty states for all views

### Changed
- Improved dark app design
- Stricter code-checks in CI

### Fixed
- Default template is now displayed correctly in campaign editor
- Paddle webhooks now have improved idempotency


## Version 0.5.0

### Added
- Added click/open tracking for campaign emails
- `Precedence: Bulk` header now included in all campaign emails
- Implemented per-instance `SharedSenders`
- Implemented Shared Senders for AWS SES
- Added account and account credits for organizing users and implementing quotas
- Added subscription plans for app.keila.io

### Changed
- Updated to Elixir 1.12

### Fixed
- Removed email preview text from Cerberus

## Version 0.4.0 🎨

Template customization & UI improvements

### Added
- Template editor for customizing Markdown campaign styles

### Changed
- Improved index pages for forms, templates, and campaigns
- Updated dependencies, using upstream of `Swoosh` again

### Fixed
- Fixed broken template download links in production


## Version 0.3.0

Scheduling campaigns & WYSIWYG editor ⏲️

### Added

- Campaigns can now be scheduled to be sent automatically
- WYSIWYG editor for Markdown campaigns
- Local sender for testing in development mode

### Fixed

- Formatted dates in local timezone now used on campaign overview page
- Removed default email preview text


## Version 0.2.2

## Fixed

- Fixed crash when starting release


## Version 0.2.1

### Fixed

- TailwindCSS styles are now pruned, massively reducing CSS size
- Default admin user is created correctly when `KEILA_USER` is not specified
- Fixed crash when starting release


## Version 0.2.0

Simplified deployments ⚙️

### Added

- Improved deployment workflow with automatic migrations
- Automatic creation of root user
- Admin panel with simple user management

### Fixed

- Campaigns can no longer be sent twice


## Version 0.1.0

First official release of Keila 🚀

### Added

This first release implements the most important features to make Keila a
viable tool for managing newsletters.

- Editor for plain text + Markdown campaigns
- Sending campaigns with SMTP, SES, Sendgrid, Mailgun
- Signup forms and form editor
- Contact import
- One-click unsubscription
