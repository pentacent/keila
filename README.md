![GitHub Workflow Status](https://img.shields.io/github/actions/workflow/status/pentacent/keila/ci.yml?label=build&style=flat-square&branch=main)
[![Docker Image Version (latest semver)](https://img.shields.io/docker/v/pentacent/keila?color=blue&label=docker%20image&style=flat-square)](https://hub.docker.com/r/pentacent/keila/tags)
[![GitHub release (latest SemVer)](https://img.shields.io/github/v/release/pentacent/keila?label=latest%20version&style=flat-square)](https://github.com/pentacent/keila/releases)
[![GitHub Sponsors](https://img.shields.io/github/sponsors/pentacent?color=ff69b4)](https://github.com/sponsors/pentacent)

<a href="https://fosstodon.org/@keila" title="Folow Keila on Mastodon" rel="me"><img src="https://img.shields.io/mastodon/follow/109370923780670804?domain=https%3A%2F%2Ffosstodon.org&label=Follow&style=flat-square&logo=mastodon&color=blue&logoColor=white"></a>
<a href="https://bsky.app/profile/pentacent.bsky.social" title="Folow the development of Keila on Bluesky"><img src="https://img.shields.io/badge/dynamic/json?url=https%3A%2F%2Fpublic.api.bsky.app%2Fxrpc%2Fapp.bsky.actor.getProfile%2F%3Factor%3Dpentacent.bsky.social&query=%24.followersCount&style=flat-square&logo=bluesky&logoColor=white&label=Bluesky"></a>


# ![The Keila logo is a stylized elephant](.github/assets/logo.svg) Keila - An Open Source Newsletter Tool

Keila is an Open Source alternative to newsletter tools like Mailchimp or
Sendinblue.

With Keila you can easily send out newsletter campaigns and create sign-up
forms.

For smaller newsletters, you can use your own email inbox to send out campaigns.
For larger newsletter projects, AWS SES, Sendgrid, Mailgun, and Postmark are supported in addition
to SMTP.

![Screenshot of the Keila campaign editor showing the WYSIWYG editor and the default template](https://www.keila.io/_astro/keila-2024-05-01.BUp8L2VZ.png)

## Give Keila a Try!

You can give a hosted version of Keila a try on [app.keila.io](https://app.keila.io/auth/register).
More information about the pricing of Keila Cloud [here](https://www.keila.io/pricing).

If you want to deploy Keila on your own server, you can use the official Docker
image `pentacent/keila` or use the [sample Docker Compose config](ops/docker-compose.yml)
in this repo.

Follow the [Installation Docs](https://www.keila.io/docs/installation)
for more details.

## Contributing

You can contribute to the Keila project with translations or code! Learn more
about how to contribute code or translations to Keila here: [CONTRIBUTING.md](CONTRIBUTING.md)


## The Name
Keila is the name of the elephant mascot of this project.
She’s a wise and diligent elephant lady, able to remember countless email
addresses and contact names.
Fun fact: Keila loves going on holiday trips to the lakes of Finland.

## License
Keila is free software. You can redistribute it and/or modify
it under the terms of the GNU Affero General Public License as
published by the Free Software Foundation, either version 3 of the
License, or (at your option) any later version.

Keila is distributed in the hope that it will be useful, but WITHOUT ANY
WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A
PARTICULAR PURPOSE.

For more details about the AGPL, please [read the full license here](LICENSE.md).

Please note that the Keila logo and all files included in the `extra` directory are not subject to the license.

For more details about the files in the `extra` directory, please refer to the [extra README](extra/README.md).
