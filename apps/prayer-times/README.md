# Prayer Times

The five daily prayers for your city, and how long until the next one.

Page one answers the only question anybody has between prayers — how long have I
got — with a bar that fills from the *previous* prayer to the next. Page two is
the whole day, with what has passed dimmed.

Data from [aladhan.com](https://aladhan.com). No account and no API key.

## Settings

| setting | what it is |
|---|---|
| **City** | 141 cities. Every one was checked against the service, so anything in the list resolves. |
| **Calculation method** | Which convention sets the Fajr and Isha angles. |

## The calculation method matters

This is not a cosmetic preference. The conventions disagree about how far below
the horizon the sun must be for Fajr and Isha, and the difference is real
minutes — enough to matter for a prayer.

Pick the one your mosque follows. Common choices:

| where | usually |
|---|---|
| Saudi Arabia | Umm Al-Qura University, Makkah |
| North America | Islamic Society of North America (ISNA) |
| Turkey | Diyanet Isleri Baskanligi |
| Malaysia | JAKIM |
| Indonesia | Kementerian Agama |
| Egypt | Egyptian General Authority of Survey |
| Pakistan, India, Bangladesh | University of Islamic Sciences, Karachi |
| elsewhere / unsure | Muslim World League |

Twenty-three methods are offered, which is all of the ones the service supports.

## The countdown uses the city's clock, not the panel's

Earlier versions assumed the panel stood in the city it was showing. Now that the
city is picked from a list it is far more likely to be somewhere else — a panel
in London showing Mecca — so the app asks the service for that city's own wall
clock and counts down against it.

That also covers the zones no fixed rule can express. Morocco steps back an hour
for Ramadan, which moves with the lunar calendar and cannot be worked out from a
date alone.

## What is not shown

Sunrise, Imsak and the thirds of the night come back in the same response and are
deliberately left out. They are not prayers, and five things fit a 192px row
cleanly.

---

Settings ride a colon-separated render descriptor, so **a value containing `:` is cut
at the first colon before the app sees it**. See [CONTRIBUTING.md](../../CONTRIBUTING.md).
