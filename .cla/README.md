# Keila Contributor License Agreement

Thank you for contributing to the Keila project.

Keila is a Free Software project under the stewardship of
Philipp Schmieder Medien (The Keila Maintainers). Before we can accept your
contribution, please sign the Contributor License Agreement (CLA).

## How does signing the CLA work?

We’ve created a [convenient little script](./sign.sh) that allows you to sign the CLA without ever leaving the command line.
The script is quite simple and well-documented, so please feel free to inspect the source code.

You can sign the CLA by running it from the main Keila folder:
`./.cla/sign.sh`

Here is how the signing process works:

1) The script shows you the [Keila CLA](./agreement.md)
2) You are asked to confirm your acceptance of the agreement by typing "yes"
3) You are asked to enter your name and email address.
   Please, if at all possible, consider using your full real name.\
   Your data will *not* be made available publicly.\
   Your name and email are encrypted
   using a public key and can only be accessed by The Keila Maintainers
   and only for the purpose of the CLA.
4) The script adds the encrypted data to the [contributors.txt](./contributors.txt) file.
5) The script asks you if you want to commit and push your signature right away.
   If you agree, the signature is committed to the current git branch and pushed to the remote repository.
   You can also do this manually afterwards.
