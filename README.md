# artifacts

Dynamic artifacts related to the Crunchyroll API, which are kept up to date automatically.

## [`credentials.json`](./credentials.json)

Contains the credentials of some Crunchyroll apps:
- Android phone
- Android TV

These are needed to make requests to the Crunchyroll API. The file is split into profiles, `<platform>_<client>`, each with the following fields:

| Field                         | Description                                                                    |
| ----------------------------- | ------------------------------------------------------------------------------ |
| `client_id` / `client_secret` | The app's API credentials, sometimes needed to issue a sessions (e.g. for SSO) |
| `basic_auth_token`            | `<client_id>:<client_secret>` base64 encoded, used when issuing a session      |
| `version`                     | The app version, part of the user agent                                        |
| `version_code`                | The app version code, part of the user agent                                   |

It's intended that you include the link to the `credentials.json` in your Crunchyroll API project, so you don't have to manually update the auth credentials and user agent when new versions are released or old auth credentials invalidated.
