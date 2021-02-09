![The Keila logo is a stylized elephant](.github/assets/logo.svg)

# Keila - An Open Source Newsletter Tool

Keila is an Open Source alternative to newsletter tools like Mailchimp or
Sendinblue.

With Keila you can easily send out newsletter campaigns and create sign-up
forms.

For smaller newsletters, you can use your own email inbox to send out campaigns.
For larger newsletter projects, AWS SES and Sendgrid are supported in addition
to SMTP.

![Screenshot of the Keila form editor showing color modification and custom texts](.github/assets/screenshot-form.png)

## Giving Keila a Try

Keila is still in development but you can already give it a try.
To run it, follow these steps:

* Clone the repository: 
  `git clone https://github.com/pentacent/keila.git`
* [Install Elixir](https://elixir-lang.org/install.html)
* Install dependencies with `mix deps.get`
* Install dependencies and set up database with `mix setup`
* Start Keila server with `mix phx.server`

Now you can visit [`localhost:4000`](http://localhost:4000) from your browser.

## The Name
Keila is the name of the elephant lady in our logo. It’s also the Finnish word
for the elephant’s tusks.

## License
Keila is free software. You can redistribute it and/or modify
it under the terms of the GNU Affero General Public License as
published by the Free Software Foundation, either version 3 of the
License, or (at your option) any later version.

For more details, please [read the full license here](LICENSE.md).

Please note that the Keila logo is not subject to the aforementioned license.
