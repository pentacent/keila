# Changelog

## Version 0.2.1

## Fixed

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