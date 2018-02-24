# encpass.sh

encpass.sh provides a lightweight solution for using encrypted passwords in shell scripts using SSH and OpenSSL. It allows a user to encrypt a password at runtime and then use it, decrypted, within another script. This prevents shoulder surfing passwords and avoids storing the password in plain text, which could inadvertently be sent to or discovered by an individual at a later date. By default, the SSH public key of the user is used to encrypt the user specified password. The encrypted password is stored in a file in the current directory. This file can then be decrypted to obtain the password using the user's SSH private key. Subsequent calls to get_password will not prompt for a password to be entered as the file with the encrypted password already exists. 

Note: It will create the following files in the current directory your script is run in:

* pass.enc (The encrypted password)
* id_rsa.pub.pem (The PKCS8 version of the public key)

## Requirements

encpass.sh requires the following software to be installed:

* POSIX compliant shell
* OpenSSL
* SSH (uses ssh-keygen)

## Installation

Clone the repo and copy the encpass.sh script to the directory where your other script resides.

## Usage

Source encpass.sh in your script and call the get_password function.

By default, encpass.sh assumes that the ssh public/private keys are accessible by the user in ~/.ssh.  You can generate unique keys, store them in a different directory, and pass that directory as an argument to this script if you don't want to use your default keys.

See the test.sh example...
```
#!/bin/sh
. ./encpass.sh
password=$(get_password)
# Call it specifying a directory
#password=$(get_password ~/.ssh)
echo $password
```

## Testing
Run unit tests for shell interpreters SH, BASH, ZSH, KSH

```
cd tests
./suite.sh
```

Testing with Docker
```
docker build -t encpass-test .
docker run --rm -it encpass-test
```

## Limitations

Ideally this script can be used in all POSIX compliant shells, but it has only been really tested within BASH.  If you encounter an issue using it in another shell please log an issue and/or submit a pull request for a fix.

It is intended that encpass.sh handles one password per directory; therefore, if you have multiple scripts that use **different passwords** that you would like to use encpass.sh for, then you should separate them into different directories.  I'm sure with a little work encpass.sh could be enhanced to track passwords for multiple scripts in the same directory.  Pull requests welcome. :-)
