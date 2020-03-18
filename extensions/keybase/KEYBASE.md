# encpass-keybase.sh - Keybase Extension

The keybase extension allows encpass.sh to use Keybase keys and encrypted git repos to store and access secrets.  This means the default OpenSSL encryption mechanism is replaced with the builtin encryption performed by the Keybase client.  When a secret is encrypted, it is encrypted with the Per-User Keys for either your Keybase user or the Keybase team your specify.  This means when someone is added to a team in Keybase they will immediately be able to clone and have access to the encpass.sh secrets in the Keybase git repo.  Also, Keybase will take care of rotating the keys for the team when a user is removed.

## Getting Started
To get started using the Keybase extension, clone the git encpass.sh repo and place the directory on your path OR place the encpass-keybase.sh script in a directory on your $PATH.  Once completed you should be able to run the following command to see that the extension is available:

```
$ encpass.sh extension list
The following extension are available:
keybase
```

To enable it simply type the following:
```
$ encpass.sh extension enable keybase
Extension keybase enabled.
```

## Additional Commands
The Keybase extension provides the following additional commands:
* create-repo (Creates a remote Keybase git repo)
* delete-repo (Deletes a remote Keybase git repo)
* clone-repo (Clones the remote Keybase git repo to your local filesystem)
* list-repos (Lists all the encpass.sh remote Keybase git repos)
* refresh (Runs a "git pull --rebase" to refresh all secrets from the remote Keybase git repos)
* status (Lists all local filesystem changes to secrets that need to be committed and pushed to the remote Keybase git repos)
* store (Commits and pushs secrets for an encpass.sh bucket to its corresponding remote Keybase git repo)

## Modifications to existing commands
The following commands are disabled for the Keybase extension:
* lock (The Keybase client software is responsible for automatically locking when you sign out)
* unlock (The Keybase client software is responsible for automatically unlocking when you sign in)
* rekey (The Keybase client software takes care rotating keys when necessary)

## Bucket creation
The first time you are creating a bucket to hold secrets you will need to do the following:
(1) Create the remote Keybase repo.
(2) Clone the remote Keybase repo to your local filesystem.
(3) Add a secret to the bucket that was created during the clone step.

You may NOT create a bucket directly using the "add" command without cloning.  This is done to ensure that the local filesystem bucket is properly setup and tracking to the remote Keybase git repo.

## Questions
If you have more questions see the help documentation by running
```
encpass.sh ?
```
