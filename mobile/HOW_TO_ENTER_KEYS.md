# How to access the app and enter your keys (RevenueScope / IronSource)

## 1. Open the app

- **Android:** Tap the RevenueScope icon on your device.
- **iOS:** Tap the RevenueScope icon on your home screen.

On first launch you will see the **IronSource Keys** (Credentials) screen.  
If you already opened the app before, tap the **Settings (gear)** icon in the top bar of the Dashboard to open the same screen.

---

## 2. Get your keys from IronSource

You need two values from the IronSource (LevelPlay) publisher platform:

1. **Secret Key**
2. **Refresh Token**

**Where to find them:**

- Log in to [IronSource / LevelPlay](https://platform.ironsrc.com/).
- Go to **My Account** (or **Account** → **My Account**).
- Find the section for **Publisher API** or **API credentials**.
- Copy your **Secret Key** and your **Refresh Token**.  
  (If you don’t see a Refresh Token, you may need to generate one from that same page.)

---

## 3. Enter the keys in the app

1. On the **IronSource Keys** screen you will see two fields:
   - **Secret Key**
   - **Refresh Token**
2. Paste your **Secret Key** into the first field.
3. Paste your **Refresh Token** into the second field.
4. Tap **Save and continue** (or **Save**).

The app will check the keys. If they are valid, you will be taken to the **Dashboard** and your data will load.

---

## 4. If you see an error

- **“Invalid keys” / “Invalid keys. Check your Secret Key and Refresh Token in Settings.”**  
  - Make sure you copied the full Secret Key and Refresh Token with no extra spaces.
  - Ensure you are using the credentials for the **Publisher API** (LevelPlay Reporting), not a different product.

- **No internet**  
  - Check your Wi‑Fi or mobile data and try again.

---

## 5. Changing the keys later

- Open the **Dashboard**.
- Tap the **Settings (gear)** icon in the top bar.
- Update the **Secret Key** and/or **Refresh Token** and tap **Save and continue**.

Keys are stored only on your device and are not sent to any server other than IronSource’s official API.
