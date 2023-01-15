# Changelog

## Unreleased

## Version 0.11.0

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