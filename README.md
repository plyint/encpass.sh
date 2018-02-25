# encpass.sh

encpass.sh provides a lightweight solution for using encrypted passwords in shell scripts using OpenSSL. It allows a user to encrypt a password (or any other secret) at runtime and then use it, decrypted, within another script. This prevents shoulder surfing passwords and avoids storing the password in plain text, which could inadvertently be sent to or discovered by an individual at a later date.

This script generates an AES 256 bit symmetric key for each script (or user-defined label) that stores secrets. This key will then be used to encrypt all secrets for that script or label.

Subsequent calls to retrieve a secret will not prompt for a secret to be entered as the file with the encrypted value already exists.

Note: encpass.sh sets up a directory (.encpass) under the user's home directory where keys and secrets will be stored.

~/.encpass will contain the following subdirectories:

* keys (Holds the private key for each script or user-defined label)
* secrets (Holds the secrets stored for each script or user-defined label)

## Requirements

encpass.sh requires the following software to be installed:

* POSIX compliant shell
* OpenSSL

## Installation

Download the encpass.sh script and install it to a directory in your path.

Example: curl the script to /usr/local/bin
```
$ curl https://raw.githubusercontent.com/ahnick/encpass.sh/master/encpass.sh -o /usr/local/bin/encpass.sh
  % Total    % Received % Xferd  Average Speed   Time    Time     Time  Current
                                 Dload  Upload   Total   Spent    Left  Speed
100  3085  100  3085    0     0   5184      0 --:--:-- --:--:-- --:--:--  5193
```

## Usage

Source encpass.sh in your script and call the get_secret function.

See the test.sh example...
```
#!/bin/sh
. encpass.sh
password=$(get_secret)
# Call it specifying a named secret
#password=$(get_secret password)
# Call it specifying a named secret for a specific label
#password=$(get_secret test.sh password)
echo $password
```

## Important Security Information

While the password is stored encrypted, once the password is decrypted within a script, the script author must take care not to inadvertently expose the password. For example, if you invoke another process from within a script that is using the decrypted password AND you pass the decrypted password to that process, then it would be visible to ps.

Imagine a script like the following...
```
#!/bin/sh
. ./encpass.sh
password=$(get_password)
watch whatever.sh --pass=$password &
ps -A
```

Upon executing you should see the password in the ps output...
```
97349 ??         9:56.30 watch whatever.sh --pass=P@$$w0rd
```

## Limitations

Ideally this script can be used in all POSIX compliant shells, but it has only been extensively tested in BASH.  If you encounter an issue using it in another shell please log an issue and/or submit a pull request for a fix.
