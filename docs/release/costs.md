# Ownership and costs

Pricing checked **2026-11-17** against the official pages linked below; USD examples
exclude tax and are estimates, not an account enrollment or spending approval.
No host, domain, developer billing arrangement or initial distribution channel
has been selected for Caption. Local drafting and fake transport tests incur no
provider API requests and need no app backend.

| Item | Expected responsibility and current limit |
| --- | --- |
| Caption application backend | None in the accepted architecture. Drafts/media/journals stay on device. A required running backend would be a new reviewed architecture decision. |
| Bluesky static OAuth metadata | The app owner maintains public HTTPS JSON and callback/domain continuity. Static hosting may fit a free provider tier; private hosting, domains, renewals and traffic can cost money. No host/domain chosen. Ordinary users do not host their own metadata. |
| X API | The official pricing documentation currently describes prepaid credits/pay per usage, with endpoint/resource rates, spending limits and optional auto-recharge. Billing owner and whether/how this applies to distributed users remain unresolved. Never assume a universally free API. |
| Bluesky account/PDS/video | Public service terms, account verification, upload quotas and rate limits apply. This repository does not establish a permanent free API/service guarantee or provide a hosted PDS. Direct access/video acceptance is blocked. |
| Instagram assistance | Caption prepares locally; no Instagram publishing API is provisioned. The user needs the receiving app/account and completes posting. Carrier/storage/device and service terms still apply. |
| Android distribution | Personal APK, direct open-source download and Play are unselected alternatives. Direct distribution needs an update/signature/hosting owner. Play currently lists a one-time US$25 registration fee plus identity/device and applicable testing requirements. No enrollment/payment has occurred. |
| Development | Flutter/Android/JDK tooling and third-party packages have their own licenses. Hardware, downloads/storage and maintenance time remain the developer's costs. |

The [X official rate page](https://docs.x.com/x-api/getting-started/pricing)
currently lists these labels and units:

| Official label | Listed rate |
| --- | --- |
| Post: Create | $0.015 per request |
| Post: Create (with URL) | $0.200 per request |
| User: Read | $0.010 per resource |
| Posts: Read | $0.005 per resource |
| Media Metadata | $0.005 per request |

For arithmetic scale only, 100 billable requests at the listed **Post: Create**
rate equal **$1.50**, before any additional operations/taxes. The public table
does not explicitly settle whether the separate with-URL rate replaces or adds
to the ordinary create charge in every account arrangement, so this record gives
no combined URL-post estimate. This is not a complete photo/video posting budget:
confirm every endpoint the accepted adapter uses and its exact billing treatment
in the [developer console](https://console.x.com) and
[pricing page](https://developer.x.com/#pricing) before authorizing a paid test.
Promotional credits and deduplication are not budget guarantees. Assign a billing
owner/spending limit and decide auto-recharge explicitly; this task makes no such
choice and purchases no credits.

Official references (retrieved successfully 2026-11-17):

- [AT Protocol OAuth profile](https://atproto.com/specs/oauth), including public
  client metadata and native-client requirements.
- [GitHub Pages availability/limits](https://docs.github.com/en/pages/getting-started-with-github-pages/about-github-pages),
  one possible static host, with no implication that GitHub has been selected.
- [Play developer registration and fee](https://support.google.com/googleplay/android-developer/answer/6112435?hl=en).
- [Play testing requirements for applicable personal accounts](https://support.google.com/googleplay/android-developer/answer/14151465?hl=en).

Recheck official pricing/terms and date this record before a public release or
provider enrollment. Source publication, a passing build and MIT selection do not
pay for API access or authorize charges.
