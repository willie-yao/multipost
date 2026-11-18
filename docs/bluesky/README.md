# Bluesky for a personal development build

Two build switches, both off by default:

- `BLUESKY_DEV_CONNECT=true` lets you **sign in** to Bluesky.
- `BLUESKY_DEV_POST=true` (needs the first) treats Bluesky's documented **text and photo** limits as accepted, so Review can publish: up to 300 characters and 4 JPEG/PNG photos. Bluesky accepts photos up to 2 MB, so a larger photo is sent as a smaller JPEG copy (long edge 2000 px or less, no metadata); Review notes this, and the photo on your device is unchanged. **Video stays blocked.** Nothing is sent until you press Publish in Review, and an interrupted send becomes "Unknown" with no automatic resend.

Ordinary builds without these switches keep Bluesky unavailable.

## What gets published

Bluesky's sign-in (atproto OAuth) needs a small public JSON file, the *client metadata*. It identifies the app and holds no secrets. The app accepts only this exact address and return link:

| Value | Setting |
| --- | --- |
| Metadata address (`client_id`) | `https://willie-yao.github.io/multipost/client-metadata.json` |
| Return link | `io.github.willie-yao:/callback` (the host name reversed, as the app requires) |

The files to host are in [`pages/`](pages/): `client-metadata.json` and a one-line `index.html`. `app/test/features/providers/app_configuration_test.dart` checks that the JSON matches what the app requires, so changing one without the other fails a test.

## Publish it (you do this; nothing here pushes)

1. On GitHub, create a public repository named **`multipost`** under `willie-yao`.
2. Copy both files from `docs/bluesky/pages/` to the repository root and commit.
3. Open **Settings → Pages**. Set "Deploy from a branch", branch `main`, folder `/ (root)`, and save.
4. After a minute, check that this command prints `200` and `application/json`, with no redirect:

   ```bash
   curl -sI https://willie-yao.github.io/multipost/client-metadata.json
   ```

   If your GitHub user site uses a custom domain, `github.io` redirects to it and the app rejects the redirect. In that case, tell Claude the domain, and the address and return link will be changed to match.

## Build and try it

From `app/`:

```bash
flutter build apk --debug --dart-define=BLUESKY_METADATA_URI=https://willie-yao.github.io/multipost/client-metadata.json --dart-define=BLUESKY_CALLBACK_SCHEME=io.github.willie-yao --dart-define=BLUESKY_DEV_CONNECT=true --dart-define=BLUESKY_DEV_POST=true
```

Ordinary builds without these values leave Bluesky unavailable.

Install it on an emulator or phone, then open **Accounts → Connect Bluesky**. Enter your handle. The app never asks for a password. Sign in on Bluesky's own page, then return to the app. Accounts should show **Connected** with your handle.

## Limits

- **Supported accounts:** only accounts hosted by Bluesky (`did:plc` on `bsky.social`). Self-hosted servers and `did:web` accounts get a named "unsupported" message.
- **Permissions:** the scopes include image and video upload and reading your account email. The email is read only to check the video upload prerequisite, which this build doesn't use because video is blocked.
- **Sign-in return:** the callback activity uses `android:taskAffinity=""` (as the sign-in plugin requires) so the sign-in tab closes when Bluesky redirects back.
- **Verified on a real phone (2026-11-18):** sign-in. **Not yet verified:** a real post, cancel, return after the app is closed, two-factor login, token refresh.
