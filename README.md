# encpass.sh

encpass.sh provides a lightweight solution for using encrypted passwords in shell scripts using OpenSSL. It allows a user to encrypt a password (or any other secret) at runtime and then use it, decrypted, within a script. This prevents shoulder surfing passwords and avoids storing the password in plain text, which could inadvertently be sent to or discovered by an individual at a later date.

This script generates an AES 256 bit symmetric key for each script (or user-defined bucket) that stores secrets. This key will then be used to encrypt all secrets for that script or bucket.

Subsequent calls to retrieve a secret will not prompt for a secret to be entered as the file with the encrypted value already exists.

Note: By default, encpass.sh sets up a directory (.encpass) under the user's home directory where keys and secrets will be stored.  This directory can be overridden by setting the environment variable ENCPASS_HOME_DIR to a directory of your choice.

~/.encpass (or the directory specified by ENCPASS_HOME_DIR) will contain the following subdirectories:

* keys (Holds the private key for each script or user-defined bucket)
* secrets (Holds the secrets stored for each script or user-defined bucket)

## Requirements

encpass.sh requires the following software to be installed:

* POSIX compliant shell environment (sh, bash, ksh, zsh)
* OpenSSL

Note: Even if you use fish or other types of modern shells, encpass.sh should still be usable as those shells typically support running POSIX compliant scripts.  You just won't be able to include encpass.sh in any fish specific scripts or other non-POSIX compliant scripts.

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

See the example.sh sample script...
```
#!/bin/sh
. encpass.sh
password=$(get_secret)
# Call it specifying a named secret
#password=$(get_secret password)
# Call it specifying a named secret for a specific label
#password=$(get_secret example.sh password)
echo $password
```

encpass.sh also provides a command line interface to perform the following management functions:
- Add secrets/buckets
- Remove secrets/buckets
- List secrets/buckets
- Show secrets/bucket
- Lock/Unlock all keys for buckets

For example...
```
$ ./encpass.sh ls example.sh
password
```

## Configuration
By default encpass.sh will create a hidden directory in the user's home directory to store all it's data (keys and secrets) in.  A different directory can be specified by setting the ENCPASS_HOME_DIR environment variable.

For example, you could store the .encpass directory on an encrypted filesystem or networked mount point such as KBFS (Keybase Filesystem).  To do this you can place the following line (substituting your own username) in your ~/.bashrc or ~/.bash_profile, so that everytime you start a shell encpass.sh will point to this location for the .encpass directory.
```
export ENCPASS_HOME_DIR=/keybase/private/<USERNAME>/.encpass
```

## Testing with Docker
encpass.sh strives to be usable in all POSIX compliant shell environments (i.e. SH, BASH, ZSH, KSH).  To verify changes to the script have not broken compliance, you can run the bundled unit tests with the repo using make. 
```
make test
```

## Important Security Information

Although encpass.sh encrypts every secret on disk within the user's home directory, once the password is decrypted within a script, the script author must take care not to inadvertently expose the password. For example, if you invoke another process from within a script that is using the decrypted password AND you pass the decrypted password to that process, then it would be visible to ps.

Imagine a script like the following...
```
#!/bin/sh
. ./encpass.sh
password=$(get_secret)
watch whatever.sh --pass=$password &
ps -A
```

Upon executing you should see the password in the ps output...
```
97349 ??         9:56.30 watch whatever.sh --pass=P@$$w0rd
```
