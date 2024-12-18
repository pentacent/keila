#!/bin/bash

# Running this script does the following:
# 1) Display the Keila CLA
# 2) Prompt for your acceptance of the CLA
# 3) Prompt for your name and email
# 4) Add your encrypted name and email to ./.cla/signatures.txt
# 5) Commit and push the updated ./.cla/signatures.txt file

confirm () {
    read -p "$1 (yes/no) " agree
    agree=$(echo -n $agree | tr '[:upper:]' '[:lower:]')
    agree=${agree:-"$2"}

    if [[ "$agree" == "y" ]] || [[ "$agree" == "yes" ]]; then
        return 0
    fi

    if [[ "$agree" == "n" ]] || [[ "$agree" == "no" ]]; then
        return 1
    fi

    confirm "$1"
}

# Get CLA directory
path=`dirname $(realpath $0)`

# Check if there are any staged files.
# We don't want to accidentally commit anything other than the signature
git_staged=$(git diff --staged)
if [ -n "$git_staged" ]; then
    echo "Please run this command only when you have no files currently staged."
    exit 1
fi

# Display the CLA and ask for acceptance
less -e "$path/agreement.md"
if ! confirm "Have you read and do you agree to the Keila CLA?"; then
    echo "Please read the CLA before you continue."
    exit 1
fi


# Prompt for name (default to git user.name)
git_name=`git config user.name`
read -p "Please enter your legal name [$git_name]: " name
name=${name:-$git_name}
git_email=`git config user.email`

# Prompt for email (default to git user.email)
read -p "Please enter your email [$git_email]: " email
email=${email:-$git_email}

# Print signature and ask for confirmation to commit and push
signature="$name <$email>"
echo -e "\nThis is the signature you're using to sign the agreement: $signature"
echo -e "Your signature will be encrypted and can only be decrypted by The Keila Maintainers."

if ! confirm "Write an encrypted version of this signature to .cla/contributors.txt? [yes]" "yes"; then
    echo "Nothing written to disk."
    exit 1
fi

echo $signature | openssl pkeyutl -encrypt -pubin -inkey "$path/key.pub" | base64 >> "$path/contributors.txt"
echo >> "$path/contributors.txt"
echo "Written signature to .cla/contributors.txt."

if ! confirm "Commit and push your signature now? [yes]" "yes"; then
    echo "You can manually commit and push your signature by running git add ./.cla/contributors.txt && git commit -m 'Sign CLA' && git push"
    exit 1
fi

git add "$path/contributors.txt"
git commit -m 'Sign CLA'
git push

echo "Thank you for signing the CLA!"

exit 0
