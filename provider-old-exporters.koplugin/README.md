# Notice

These are highlight exporters that were deprecated on the main repo.

They're provided as is. Do no expect them to be useful ;)


## Memos / Flomo

Deprecated reason: reported as broken, received no support

### Original instructions

Create your Access Token from the `Settings` menu of your Memos installation and use it in Koreader's `Set Memos Token` field. The `Set Memos API URL` should have the following format:
`http://<your-memos-IP>:<port>/api/v1/memos` 
or 
`https://your-memos.tld/api/v1/memos` 

Since the token is very long, you may find it easier to create a random string in Koreader, then edit the file `settings.reader.lua` located in Koreader -> Settings: find your random string and paste your token over it. Alternatively, create a file with your token and save it to your Koreader docs, then open it from within Koreader like any other book, copy the token, and paste it in the relevant settings field.

